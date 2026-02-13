import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import uuid

from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, FieldCondition, Filter, MatchValue, PointStruct, VectorParams


def log(message: str) -> None:
    timestamp = dt.datetime.now(dt.timezone.utc).isoformat()
    print(f"[{timestamp}] {message}")


def read_file(path: pathlib.Path) -> bytes:
    with path.open("rb") as handle:
        return handle.read()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_state(path: pathlib.Path) -> dict:
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError:
        return {}


def save_state(path: pathlib.Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2, sort_keys=True)


def pdf_to_text(pdf_path: pathlib.Path, pdftotext_bin: str) -> str:
    result = subprocess.run(
        [
            pdftotext_bin,
            "-layout",
            "-enc",
            "UTF-8",
            str(pdf_path),
            "-",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def normalize_text(text: str) -> str:
    cleaned = text.replace("\x00", " ")
    lines = [line.strip() for line in cleaned.splitlines()]
    non_empty = [line for line in lines if line]
    return "\n".join(non_empty)


def chunk_words(text: str, max_words: int, overlap: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    chunks = []
    step = max_words - overlap if max_words > overlap else max_words
    index = 0
    while index < len(words):
        chunk = words[index : index + max_words]
        chunks.append(" ".join(chunk))
        index += step
    return chunks


def ensure_collection(client: QdrantClient, name: str, vector_size: int) -> None:
    if client.collection_exists(name):
        return
    client.create_collection(
        collection_name=name,
        vectors_config=VectorParams(size=vector_size, distance=Distance.COSINE),
    )


def delete_existing_for_file(client: QdrantClient, collection: str, source_path: str) -> None:
    client.delete(
        collection_name=collection,
        points_selector=Filter(
            must=[
                FieldCondition(
                    key="source_path",
                    match=MatchValue(value=source_path),
                )
            ]
        ),
    )


def embed_batch(client: OpenAI, model: str, texts: list[str], batch_size: int) -> list[list[float]]:
    embeddings: list[list[float]] = []
    for start in range(0, len(texts), batch_size):
        batch = texts[start : start + batch_size]
        response = client.embeddings.create(model=model, input=batch)
        embeddings.extend([item.embedding for item in response.data])
    return embeddings


def upsert_batches(
    client: QdrantClient,
    collection: str,
    points: list[PointStruct],
    batch_size: int,
) -> None:
    for start in range(0, len(points), batch_size):
        batch = points[start : start + batch_size]
        client.upsert(collection_name=collection, points=batch)


def infer_project(root: pathlib.Path, pdf_path: pathlib.Path) -> str:
    rel = pdf_path.relative_to(root)
    return rel.parts[0]


def iter_pdfs(root: pathlib.Path) -> list[pathlib.Path]:
    return sorted(root.glob("*/pdfs/**/*.pdf"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan", action="store_true", help="Scan and index PDFs")
    args = parser.parse_args()

    if not args.scan:
        parser.print_help()
        return 1

    projects_root = pathlib.Path(
        os.environ.get("RAG_PROJECTS_ROOT", "/pool1/appdata/rag/projects")
    )
    collection = os.environ.get("RAG_COLLECTION", "rag_chunks")
    qdrant_url = os.environ.get("RAG_QDRANT_URL", "http://127.0.0.1:6333")
    pdftotext_bin = os.environ.get("PDFTOTEXT_BIN", "pdftotext")
    state_file = pathlib.Path(
        os.environ.get("RAG_STATE_FILE", "/var/lib/rag-indexer/state.json")
    )
    embedding_model = os.environ.get("RAG_EMBEDDING_MODEL", "text-embedding-3-small")
    litellm_base_url = os.environ.get("LITELLM_BASE_URL", "http://127.0.0.1:4000/v1")
    litellm_key_file = os.environ.get("LITELLM_API_KEY_FILE")
    chunk_words_limit = int(os.environ.get("RAG_CHUNK_WORDS", "200"))
    chunk_overlap = int(os.environ.get("RAG_CHUNK_OVERLAP", "40"))
    embed_batch_size = int(os.environ.get("RAG_EMBED_BATCH_SIZE", "32"))
    upsert_batch_size = int(os.environ.get("RAG_UPSERT_BATCH_SIZE", "128"))

    api_key = os.environ.get("LITELLM_API_KEY")
    if litellm_key_file and pathlib.Path(litellm_key_file).exists():
        api_key = pathlib.Path(litellm_key_file).read_text(encoding="utf-8").strip()
    if not api_key:
        api_key = "unused"

    qdrant_timeout = float(os.environ.get("RAG_QDRANT_TIMEOUT", "60"))
    qdrant_client = QdrantClient(url=qdrant_url, timeout=qdrant_timeout)
    openai_client = OpenAI(api_key=api_key, base_url=litellm_base_url)

    state = load_state(state_file)
    pdfs = iter_pdfs(projects_root)
    if not pdfs:
        log(f"No PDFs found under {projects_root}")
        return 0

    for pdf_path in pdfs:
        try:
            file_bytes = read_file(pdf_path)
        except OSError as exc:
            log(f"Failed to read {pdf_path}: {exc}")
            continue

        digest = sha256_bytes(file_bytes)
        key = str(pdf_path)
        if state.get(key) == digest:
            continue

        log(f"Indexing {pdf_path}")
        try:
            raw_text = pdf_to_text(pdf_path, pdftotext_bin)
        except subprocess.CalledProcessError as exc:
            log(f"pdftotext failed for {pdf_path}: {exc}")
            continue

        normalized = normalize_text(raw_text)
        chunks = chunk_words(normalized, chunk_words_limit, chunk_overlap)
        if not chunks:
            log(f"No extractable text for {pdf_path}")
            state[key] = digest
            continue

        embeddings = embed_batch(openai_client, embedding_model, chunks, embed_batch_size)
        if not embeddings:
            log(f"Embedding failed for {pdf_path}")
            continue

        ensure_collection(qdrant_client, collection, len(embeddings[0]))
        delete_existing_for_file(qdrant_client, collection, key)

        project = infer_project(projects_root, pdf_path)
        now_iso = dt.datetime.now(dt.timezone.utc).isoformat()
        points = []
        for index, (chunk, vector) in enumerate(zip(chunks, embeddings)):
            point_id = uuid.uuid5(uuid.NAMESPACE_URL, f"{digest}:{index}").hex
            points.append(
                PointStruct(
                    id=point_id,
                    vector=vector,
                    payload={
                        "project": project,
                        "source_path": key,
                        "file_name": pdf_path.name,
                        "chunk_index": index,
                        "sha256": digest,
                        "text": chunk,
                        "indexed_at": now_iso,
                    },
                )
            )

        upsert_batches(qdrant_client, collection, points, upsert_batch_size)
        state[key] = digest

    save_state(state_file, state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
