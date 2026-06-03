"""Tailnet thought-capture service.

Accepts audio or text captures, transcribes audio through an STT endpoint,
asks an OpenAI-compatible model to normalize the thought into structured JSON,
and stores successful captures in a simple file-backed index.
"""

from __future__ import annotations

import html
import json
import os
import re
import shutil
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests
from flask import Flask, Response, jsonify, request

app = Flask(__name__)

DATA_DIR = Path(os.environ.get("THOUGHT_CAPTURE_DATA_DIR", "/var/lib/thought-capture"))
STT_URL = os.environ.get("THOUGHT_CAPTURE_STT_URL", "https://stt.bepis.lol/inference")
LLM_BASE_URL = os.environ.get("THOUGHT_CAPTURE_LLM_BASE_URL", "https://litellm.bepis.lol/v1").rstrip("/")
LLM_MODEL = os.environ.get("THOUGHT_CAPTURE_LLM_MODEL", "gpt-5-mini")
HOST = os.environ.get("THOUGHT_CAPTURE_HOST", "0.0.0.0")
PORT = int(os.environ.get("THOUGHT_CAPTURE_PORT", "8787"))

INDEX_LOCK = threading.Lock()

SYSTEM_PROMPT = """You are a private thought-capture ingestion engine.

Your job is to transform a rough spoken transcript into durable structured memory.
Do not create tasks, reminders, tickets, calendar events, or commitments.
Treat the capture as on-demand reference material only.

Return strict JSON only, with this exact top-level shape:
{
  "title": "short descriptive title",
  "summary": "1-3 sentence cleaned summary",
  "interpretation": "best interpretation of what the user meant and why it may matter",
  "kind": "idea | question | reminder | design-thought | personal | errand | note | other",
  "tags": ["short", "kebab-case", "tags"],
  "projects": [
    {"name": "project or domain name", "confidence": 0.0, "reason": "why it is relevant"}
  ],
  "importance": "low | medium | high",
  "urgency": "none | low | medium | high",
  "follow_up_value": "low | medium | high",
  "status": "stored",
  "questions": ["optional clarifying questions worth asking later"]
}

Prefer honest uncertainty over over-classification. If project relevance is unclear,
use broad domains like "personal", "workflow", or "unknown" with low confidence.
"""


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def now_id() -> tuple[str, str]:
    created_at = utc_now().isoformat(timespec="seconds")
    safe_time = created_at.replace(":", "-").replace("+00:00", "Z")
    return f"{safe_time}-{uuid.uuid4().hex[:8]}", created_at


def api_key() -> str:
    direct = os.environ.get("THOUGHT_CAPTURE_LLM_API_KEY", "").strip()
    if direct:
        return direct

    key_file = os.environ.get("THOUGHT_CAPTURE_LLM_API_KEY_FILE", "").strip()
    if not key_file:
        return ""

    try:
        return Path(key_file).read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def ensure_data_dir() -> None:
    (DATA_DIR / "captures").mkdir(parents=True, exist_ok=True)


def index_path() -> Path:
    return DATA_DIR / "index.jsonl"


def read_index() -> list[dict[str, Any]]:
    path = index_path()
    if not path.exists():
        return []

    entries: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def append_index(entry: dict[str, Any]) -> None:
    ensure_data_dir()
    with INDEX_LOCK:
        with index_path().open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")


def compact_index_entry(capture: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": capture["id"],
        "created_at": capture["created_at"],
        "title": capture.get("title", "Untitled thought"),
        "summary": capture.get("summary", ""),
        "interpretation": capture.get("interpretation", ""),
        "kind": capture.get("kind", "note"),
        "tags": capture.get("tags", []),
        "projects": capture.get("projects", []),
        "importance": capture.get("importance", "medium"),
        "urgency": capture.get("urgency", "none"),
        "follow_up_value": capture.get("follow_up_value", "medium"),
        "questions": capture.get("questions", []),
        "transcript": capture.get("transcript", ""),
        "note_path": capture.get("note_path", ""),
    }


def extract_transcript(stt_response: dict[str, Any]) -> str:
    candidates = [
        stt_response.get("text"),
        stt_response.get("transcription"),
        stt_response.get("data", {}).get("text") if isinstance(stt_response.get("data"), dict) else None,
        stt_response.get("result", {}).get("text") if isinstance(stt_response.get("result"), dict) else None,
    ]
    for candidate in candidates:
        if isinstance(candidate, str) and candidate.strip():
            return candidate.strip()
    raise ValueError("STT response did not contain transcript text")


def transcribe_audio(audio_path: Path, filename: str) -> str:
    with audio_path.open("rb") as audio:
        response = requests.post(
            STT_URL,
            files={"file": (filename, audio, "audio/wav")},
            data={
                "temperature": "0.0",
                "temperature_inc": "0.0",
                "response_format": "json",
            },
            timeout=(5, 90),
        )
    response.raise_for_status()
    return extract_transcript(response.json())


def parse_llm_json(content: str) -> dict[str, Any]:
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", content, flags=re.DOTALL)
        if not match:
            raise
        parsed = json.loads(match.group(0))

    if not isinstance(parsed, dict):
        raise ValueError("LLM response was not a JSON object")
    return parsed


def analyze_transcript(transcript: str, source: dict[str, Any]) -> dict[str, Any]:
    key = api_key()
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"

    payload = {
        "model": LLM_MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "transcript": transcript,
                        "source": source,
                    },
                    ensure_ascii=False,
                ),
            },
        ],
        "temperature": 0.2,
        "max_tokens": 1400,
        "response_format": {"type": "json_object"},
    }

    response = requests.post(
        f"{LLM_BASE_URL}/chat/completions",
        headers=headers,
        json=payload,
        timeout=(10, 120),
    )
    response.raise_for_status()
    llm_response = response.json()
    content = llm_response["choices"][0]["message"]["content"]
    if isinstance(content, list):
        content = "".join(
            part.get("text", "") if isinstance(part, dict) else str(part) for part in content
        )
    if not isinstance(content, str):
        content = str(content)
    return parse_llm_json(content)


def normalize_str(value: Any, default: str) -> str:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return default


def normalize_tags(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    tags: list[str] = []
    for item in value:
        if not isinstance(item, str):
            continue
        tag = re.sub(r"[^a-z0-9]+", "-", item.lower()).strip("-")
        if tag and tag not in tags:
            tags.append(tag)
    return tags[:12]


def normalize_projects(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []

    projects: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, str):
            name = item.strip()
            confidence = 0.5
            reason = "model inferred relevance"
        elif isinstance(item, dict):
            name = normalize_str(item.get("name"), "").strip()
            try:
                confidence = float(item.get("confidence", 0.5))
            except (TypeError, ValueError):
                confidence = 0.5
            reason = normalize_str(item.get("reason"), "model inferred relevance")
        else:
            continue

        if not name:
            continue
        confidence = max(0.0, min(1.0, confidence))
        projects.append({"name": name, "confidence": confidence, "reason": reason})
    return projects[:8]


def normalize_questions(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item.strip() for item in value if isinstance(item, str) and item.strip()][:8]


def normalize_analysis(analysis: dict[str, Any], transcript: str) -> dict[str, Any]:
    return {
        "title": normalize_str(analysis.get("title"), "Untitled thought"),
        "summary": normalize_str(analysis.get("summary"), transcript[:300]),
        "interpretation": normalize_str(analysis.get("interpretation"), ""),
        "kind": normalize_str(analysis.get("kind"), "note"),
        "tags": normalize_tags(analysis.get("tags")),
        "projects": normalize_projects(analysis.get("projects")),
        "importance": normalize_str(analysis.get("importance"), "medium"),
        "urgency": normalize_str(analysis.get("urgency"), "none"),
        "follow_up_value": normalize_str(analysis.get("follow_up_value"), "medium"),
        "status": "stored",
        "questions": normalize_questions(analysis.get("questions")),
    }


def render_note(capture: dict[str, Any]) -> str:
    projects = capture.get("projects", [])
    project_lines = "\n".join(
        f"- {project.get('name', 'unknown')} ({project.get('confidence', 0):.2f}): {project.get('reason', '')}"
        for project in projects
    ) or "- none"

    tag_text = ", ".join(capture.get("tags", [])) or "none"
    question_lines = "\n".join(f"- {question}" for question in capture.get("questions", [])) or "- none"

    return f"""---
id: {capture['id']}
created_at: {capture['created_at']}
kind: {capture.get('kind', 'note')}
importance: {capture.get('importance', 'medium')}
urgency: {capture.get('urgency', 'none')}
follow_up_value: {capture.get('follow_up_value', 'medium')}
tags: [{tag_text}]
---

# {capture.get('title', 'Untitled thought')}

## Summary

{capture.get('summary', '')}

## Interpretation

{capture.get('interpretation', '')}

## Projects

{project_lines}

## Questions

{question_lines}

## Raw transcript

{capture.get('transcript', '')}
"""


def store_capture(
    *,
    capture_id: str,
    created_at: str,
    capture_dir: Path,
    transcript: str,
    source: dict[str, Any],
    audio_filename: str | None = None,
) -> dict[str, Any]:
    analysis = normalize_analysis(analyze_transcript(transcript, source), transcript)
    capture = {
        "id": capture_id,
        "created_at": created_at,
        "source": source,
        "audio_filename": audio_filename,
        "transcript": transcript,
        **analysis,
    }

    transcript_path = capture_dir / "transcript.txt"
    analysis_path = capture_dir / "analysis.json"
    note_path = capture_dir / "note.md"

    transcript_path.write_text(transcript + "\n", encoding="utf-8")
    analysis_path.write_text(json.dumps(capture, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    note_path.write_text(render_note(capture), encoding="utf-8")

    capture["note_path"] = str(note_path)
    append_index(compact_index_entry(capture))
    return capture


def new_capture_dir(capture_id: str, created_at: str) -> Path:
    date = created_at[:10]
    capture_dir = DATA_DIR / "captures" / date / capture_id
    capture_dir.mkdir(parents=True, exist_ok=False)
    return capture_dir


def source_from_request(extra: dict[str, Any] | None = None) -> dict[str, Any]:
    source: dict[str, Any] = {
        "remote_addr": request.remote_addr,
        "user_agent": request.headers.get("User-Agent", ""),
    }
    for key in ["source", "source_host", "client", "context"]:
        value = request.form.get(key) if request.form else None
        if value:
            source[key] = value
    if extra:
        source.update(extra)
    return source


def error_response(message: str, status: int = 500) -> tuple[Response, int]:
    return jsonify({"error": message}), status


@app.get("/health")
def health() -> Response:
    return jsonify(
        {
            "status": "ok",
            "model": LLM_MODEL,
            "stt_url": STT_URL,
            "data_dir": str(DATA_DIR),
        }
    )


@app.post("/api/captures/audio")
def capture_audio() -> tuple[Response, int] | Response:
    upload = request.files.get("file")
    if upload is None:
        return error_response("missing multipart field: file", 400)

    capture_id, created_at = now_id()
    capture_dir = new_capture_dir(capture_id, created_at)
    filename = upload.filename or "capture.wav"
    audio_path = capture_dir / "audio.wav"

    try:
        upload.save(audio_path)
        transcript = transcribe_audio(audio_path, filename)
        capture = store_capture(
            capture_id=capture_id,
            created_at=created_at,
            capture_dir=capture_dir,
            transcript=transcript,
            source=source_from_request({"type": "audio"}),
            audio_filename=filename,
        )
    except Exception as exc:  # discard failed captures for the MVP
        shutil.rmtree(capture_dir, ignore_errors=True)
        return error_response(f"capture failed: {exc}", 502)

    return jsonify({"capture": compact_index_entry(capture)})


@app.post("/api/captures/text")
def capture_text() -> tuple[Response, int] | Response:
    data = request.get_json(silent=True) or {}
    text = data.get("text", "")
    if not isinstance(text, str) or not text.strip():
        return error_response("missing JSON string field: text", 400)

    capture_id, created_at = now_id()
    capture_dir = new_capture_dir(capture_id, created_at)

    text_source = data.get("source", {})
    if not isinstance(text_source, dict):
        text_source = {}

    try:
        capture = store_capture(
            capture_id=capture_id,
            created_at=created_at,
            capture_dir=capture_dir,
            transcript=text.strip(),
            source=source_from_request({"type": "text", **text_source}),
        )
    except Exception as exc:
        shutil.rmtree(capture_dir, ignore_errors=True)
        return error_response(f"capture failed: {exc}", 502)

    return jsonify({"capture": compact_index_entry(capture)})


@app.get("/api/recent")
def recent() -> Response:
    try:
        limit = max(1, min(100, int(request.args.get("limit", "20"))))
    except ValueError:
        limit = 20
    entries = sorted(read_index(), key=lambda entry: entry.get("created_at", ""), reverse=True)
    return jsonify({"captures": entries[:limit]})


@app.get("/api/search")
def search() -> Response:
    query = request.args.get("q", "").strip().lower()
    try:
        limit = max(1, min(100, int(request.args.get("limit", "20"))))
    except ValueError:
        limit = 20

    entries = sorted(read_index(), key=lambda entry: entry.get("created_at", ""), reverse=True)
    if query:
        terms = query.split()

        def matches(entry: dict[str, Any]) -> bool:
            haystack = json.dumps(entry, ensure_ascii=False).lower()
            return all(term in haystack for term in terms)

        entries = [entry for entry in entries if matches(entry)]

    return jsonify({"captures": entries[:limit], "query": query})


def render_cards(entries: list[dict[str, Any]]) -> str:
    cards = []
    for entry in entries:
        tags = " ".join(f"<span>{html.escape(tag)}</span>" for tag in entry.get("tags", []))
        projects = ", ".join(
            project.get("name", "unknown") if isinstance(project, dict) else str(project)
            for project in entry.get("projects", [])
        )
        cards.append(
            f"""
            <article class="card">
              <h2>{html.escape(entry.get('title', 'Untitled thought'))}</h2>
              <p class="meta">{html.escape(entry.get('created_at', ''))} · {html.escape(entry.get('kind', 'note'))} · importance {html.escape(entry.get('importance', 'medium'))}</p>
              <p>{html.escape(entry.get('summary', ''))}</p>
              <p class="small"><strong>Projects:</strong> {html.escape(projects or 'none')}</p>
              <p class="tags">{tags}</p>
            </article>
            """
        )
    return "\n".join(cards) or "<p>No captures found.</p>"


@app.get("/")
def home() -> Response:
    query = request.args.get("q", "").strip()
    entries = sorted(read_index(), key=lambda entry: entry.get("created_at", ""), reverse=True)
    if query:
        terms = query.lower().split()
        entries = [
            entry
            for entry in entries
            if all(term in json.dumps(entry, ensure_ascii=False).lower() for term in terms)
        ]
    entries = entries[:50]

    body = f"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Thought Capture</title>
      <style>
        body {{ font-family: system-ui, sans-serif; margin: 0; background: #111318; color: #eceff4; }}
        main {{ max-width: 900px; margin: 0 auto; padding: 2rem; }}
        input {{ width: 100%; box-sizing: border-box; padding: 1rem; border-radius: 0.7rem; border: 1px solid #3b4252; background: #1f2430; color: #eceff4; font-size: 1rem; }}
        .card {{ margin: 1rem 0; padding: 1rem; border: 1px solid #2e3440; border-radius: 0.8rem; background: #1a1d26; }}
        h1, h2 {{ margin-top: 0; }}
        .meta, .small {{ color: #aeb6c6; }}
        .tags span {{ display: inline-block; margin: 0 0.35rem 0.35rem 0; padding: 0.2rem 0.45rem; border-radius: 999px; background: #2e3440; color: #d8dee9; font-size: 0.85rem; }}
      </style>
    </head>
    <body>
      <main>
        <h1>Thought Capture</h1>
        <form method="get">
          <input name="q" value="{html.escape(query)}" placeholder="Search captured thoughts">
        </form>
        {render_cards(entries)}
      </main>
    </body>
    </html>
    """
    return Response(body, mimetype="text/html")


def main() -> None:
    ensure_data_dir()
    app.run(host=HOST, port=PORT, threaded=True)


if __name__ == "__main__":
    main()
