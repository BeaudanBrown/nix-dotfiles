import os
import pathlib
import shutil
import subprocess
from typing import Optional

from fastmcp import FastMCP
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import FieldCondition, Filter, MatchValue


mcp = FastMCP("RAG")


def log(message: str) -> None:
    print(f"[rag-mcp] {message}", flush=True)


def read_api_key() -> str:
    key = os.environ.get("LITELLM_API_KEY")
    key_file = os.environ.get("LITELLM_API_KEY_FILE")
    if key_file and pathlib.Path(key_file).exists():
        key = pathlib.Path(key_file).read_text(encoding="utf-8").strip()
    return key or "unused"


def build_clients() -> tuple[QdrantClient, OpenAI, str, str]:
    qdrant_url = os.environ.get("RAG_QDRANT_URL", "http://127.0.0.1:6333")
    qdrant_timeout = float(os.environ.get("RAG_QDRANT_TIMEOUT", "60"))
    collection = os.environ.get("RAG_COLLECTION", "rag_chunks")
    embedding_model = os.environ.get("RAG_EMBEDDING_MODEL", "text-embedding-3-small")
    litellm_base_url = os.environ.get("LITELLM_BASE_URL", "http://127.0.0.1:4000/v1")

    log(
        f"Initializing clients with qdrant_url={qdrant_url}, "
        f"collection={collection}, embedding_model={embedding_model}, "
        f"litellm_base_url={litellm_base_url}, timeout={qdrant_timeout}"
    )

    qdrant_client = QdrantClient(url=qdrant_url, timeout=qdrant_timeout, prefer_grpc=False)
    openai_client = OpenAI(api_key=read_api_key(), base_url=litellm_base_url)

    return qdrant_client, openai_client, collection, embedding_model


def qdrant_search(
    client: QdrantClient,
    *,
    collection: str,
    query_vector: list[float],
    query_filter: Optional[Filter],
    limit: int,
):
    """Compatibility wrapper across qdrant-client versions."""
    if hasattr(client, "search"):
        return client.search(
            collection_name=collection,
            query_vector=query_vector,
            query_filter=query_filter,
            limit=limit,
        )

    if hasattr(client, "search_points"):
        return client.search_points(
            collection_name=collection,
            vector=query_vector,
            query_filter=query_filter,
            limit=limit,
        )

    if hasattr(client, "query_points"):
        result = client.query_points(
            collection_name=collection,
            query=query_vector,
            query_filter=query_filter,
            limit=limit,
        )
        return result.points

    raise AttributeError(
        "Unsupported qdrant-client: expected search/search_points/query_points"
    )


@mcp.tool
def rag_search(
    query: str,
    project: Optional[str] = None,
    file: Optional[str] = None,
    limit: int = 5,
) -> list[dict]:
    """Search the RAG store for relevant PDF chunks."""
    qdrant_client, openai_client, collection, embedding_model = build_clients()
    log(f"rag_search query={query!r} project={project!r} file={file!r} limit={limit}")

    filters = []
    if project:
        filters.append(
            FieldCondition(key="project", match=MatchValue(value=project))
        )
    if file:
        key = "source_path" if "/" in file else "file_name"
        filters.append(FieldCondition(key=key, match=MatchValue(value=file)))

    query_embedding = openai_client.embeddings.create(
        model=embedding_model,
        input=[query],
    ).data[0].embedding

    try:
        hits = qdrant_search(
            qdrant_client,
            collection=collection,
            query_vector=query_embedding,
            query_filter=Filter(must=filters) if filters else None,
            limit=limit,
        )
    except Exception as exc:
        log(f"Qdrant search failed: {exc}")
        raise

    results = []
    for hit in hits:
        payload = hit.payload or {}
        results.append(
            {
                "score": hit.score,
                "project": payload.get("project"),
                "file_name": payload.get("file_name"),
                "source_path": payload.get("source_path"),
                "chunk_index": payload.get("chunk_index"),
                "text": payload.get("text"),
            }
        )
    return results


@mcp.tool
def rag_import_pdf(path: str, project: Optional[str] = None) -> dict:
    """Import a PDF into the RAG store by filename.

    The 'path' should be a filename (e.g. 'manual.pdf') already present
    in the upload staging area, or an absolute path on the NAS filesystem.
    """
    projects_root = pathlib.Path(
        os.environ.get("RAG_PROJECTS_ROOT", "/pool1/appdata/rag/projects")
    )

    if not project:
        raise ValueError("Project name is required for PDF import")

    src = pathlib.Path(path).expanduser().resolve()
    if not src.exists():
        raise FileNotFoundError(f"PDF not found: {src}")
    if src.suffix.lower() != ".pdf":
        raise ValueError("Only .pdf files are supported")

    dest_dir = projects_root / project / "pdfs"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / src.name
    shutil.copy2(str(src), str(dest))

    indexer_cmd = os.environ.get("RAG_INDEXER_CMD")
    if indexer_cmd:
        log(f"Triggering indexer: {indexer_cmd}")
        subprocess.run(indexer_cmd, shell=True, check=True)

    return {
        "project": project,
        "file_name": src.name,
        "dest_path": str(dest),
        "note": "PDF copied and indexer triggered.",
    }


if __name__ == "__main__":
    host = os.environ.get("RAG_MCP_HOST", "127.0.0.1")
    port = int(os.environ.get("RAG_MCP_PORT", "8766"))
    log(f"Starting RAG MCP server on {host}:{port}")
    mcp.run(transport="sse", host=host, port=port)
