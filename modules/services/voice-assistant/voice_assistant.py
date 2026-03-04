#!/usr/bin/env python3
"""Voice Assistant LLM Proxy - A simple Flask service to proxy LiteLLM with structured output."""

import json
import os
import sys
import urllib.error
import urllib.request

from flask import Flask, jsonify, request

app = Flask(__name__)

# Configuration from environment
LITELLM_URL = os.environ.get("LITELLM_URL", "http://127.0.0.1:4000/v1/chat/completions")
API_KEY = os.environ.get("LITELLM_API_KEY", "").strip()

# Mode-specific system prompts
PROMPTS = {
    "speak": """You are a helpful voice assistant. Provide a concise, natural-sounding response suitable for text-to-speech.

Guidelines:
- Keep responses brief (1-3 sentences ideally)
- Use natural spoken language, avoid bullet points or formatting
- Include both a short speakable version and the full detailed answer

Return your response as JSON with this exact structure:
{
  "spoken": "A concise, natural-sounding spoken response (1-2 sentences)",
  "text": "The full detailed answer that can be copied/pasted"
}""",
}


@app.route("/ask", methods=["POST"])
def ask():
    """Handle assistant requests: STT text -> LLM -> structured response."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body"}), 400

        user_text = data.get("text", "").strip()
        model = data.get("model", "gpt-5-mini")
        mode = data.get("mode", "speak")

        if not user_text:
            return jsonify({"error": "No text provided"}), 400

        system_prompt = PROMPTS.get(mode, PROMPTS["speak"])

        # Build LiteLLM request
        llm_payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_text},
            ],
            "temperature": 0.7,
            "max_tokens": 1000,
            "response_format": {"type": "json_object"},
        }

        req = urllib.request.Request(
            LITELLM_URL,
            data=json.dumps(llm_payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {API_KEY}",
            },
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=60) as resp:
            llm_response = json.loads(resp.read().decode("utf-8"))

        content = llm_response["choices"][0]["message"]["content"]

        # Parse the JSON response from the model
        try:
            parsed = json.loads(content)
            spoken = parsed.get("spoken", content[:200])
            text = parsed.get("text", content)
        except json.JSONDecodeError:
            # Fallback if model doesn't return valid JSON
            spoken = content[:200]
            text = content

        return jsonify({"spoken": spoken, "text": text, "model": model})

    except urllib.error.HTTPError as e:
        return (
            jsonify(
                {"error": f"LiteLLM error: {e.code} - {e.read().decode()}"}
            ),
            502,
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok"})


def main():
    """Run the Flask application."""
    port = int(os.environ.get("PORT", "8080"))
    # Bind to localhost only; nginx handles external access
    app.run(host="127.0.0.1", port=port, threaded=True)


if __name__ == "__main__":
    main()
