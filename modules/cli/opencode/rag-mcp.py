import os
import pathlib
import shlex
import subprocess
from typing import Optional

from fastmcp import FastMCP
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import FieldCondition, Filter, MatchValue


mcp = FastMCP("RAG")


def log(message: str) -> None:
    print(f"[rag-mcp] {message}")


def read_api_key() -> str:
    key = os.environ.get("LITELLM_API_KEY")
    key_file = os.environ.get("LITELLM_API_KEY_FILE")
    if key_file and pathlib.Path(key_file).exists():
        key = pathlib.Path(key_file).read_text(encoding="utf-8").strip()
    return key or "unused"


def infer_project() -> Optional[str]:
    default_project = os.environ.get("RAG_DEFAULT_PROJECT")
    if default_project:
        return default_project
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return pathlib.Path(result.stdout.strip()).name


def build_clients() -> tuple[QdrantClient, OpenAI, str, str]:
    qdrant_url = os.environ.get("RAG_QDRANT_URL", "http://127.0.0.1:6333")
    qdrant_host = os.environ.get("RAG_QDRANT_HOST")
    qdrant_port = os.environ.get("RAG_QDRANT_PORT")
    qdrant_https = os.environ.get("RAG_QDRANT_HTTPS")
    qdrant_timeout = float(os.environ.get("RAG_QDRANT_TIMEOUT", "60"))
    collection = os.environ.get("RAG_COLLECTION", "rag_chunks")
    embedding_model = os.environ.get("RAG_EMBEDDING_MODEL", "text-embedding-3-small")
    litellm_base_url = os.environ.get("LITELLM_BASE_URL", "http://127.0.0.1:4000/v1")

    log(
        "Initializing clients with qdrant_url="
        f"{qdrant_url}, qdrant_host={qdrant_host}, qdrant_port={qdrant_port}, "
        f"collection={collection}, embedding_model={embedding_model}, "
        f"litellm_base_url={litellm_base_url}, timeout={qdrant_timeout}"
    )

    if qdrant_host and qdrant_port:
        https_enabled = str(qdrant_https or "").lower() in {"1", "true", "yes"}
        qdrant_client = QdrantClient(
            host=qdrant_host,
            port=int(qdrant_port),
            https=https_enabled,
            timeout=qdrant_timeout,
            prefer_grpc=False,
        )
    else:
        qdrant_client = QdrantClient(
            url=qdrant_url,
            timeout=qdrant_timeout,
            prefer_grpc=False,
        )
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
        log("Using QdrantClient.search")
        return client.search(
            collection_name=collection,
            query_vector=query_vector,
            query_filter=query_filter,
            limit=limit,
        )

    # Newer clients moved to *_points APIs.
    if hasattr(client, "search_points"):
        log("Using QdrantClient.search_points")
        result = client.search_points(
            collection_name=collection,
            vector=query_vector,
            query_filter=query_filter,
            limit=limit,
        )
        # search_points returns a list of ScoredPoint
        return result

    if hasattr(client, "query_points"):
        log("Using QdrantClient.query_points")
        result = client.query_points(
            collection_name=collection,
            query=query_vector,
            query_filter=query_filter,
            limit=limit,
        )
        # query_points returns an object with .points
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
    log(f"rag_search query={query!r} limit={limit}")
    project_name = project or infer_project()

    filters = []
    if project_name:
        filters.append(
            FieldCondition(key="project", match=MatchValue(value=project_name))
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
    """Upload a local PDF into the NAS RAG project folder."""
    src = pathlib.Path(path).expanduser().resolve()
    if not src.exists():
        raise FileNotFoundError(f"PDF not found: {src}")
    if src.suffix.lower() != ".pdf":
        raise ValueError("Only .pdf files are supported")

    project_name = project or infer_project()
    if not project_name:
        raise ValueError("Project name is required (could not infer from git repo)")

    ssh_target = os.environ.get("RAG_SSH_TARGET", "beau@nas")
    projects_root = os.environ.get("RAG_NAS_PROJECTS_ROOT", "/pool1/appdata/rag/projects")
    dest_dir = f"{projects_root}/{project_name}/pdfs"

    subprocess.run(
        ["ssh", ssh_target, f"mkdir -p {shlex.quote(dest_dir)}"],
        check=True,
    )
    subprocess.run(
        ["rsync", "-a", str(src), f"{ssh_target}:{dest_dir}/"],
        check=True,
    )

    trigger_cmd = os.environ.get("RAG_TRIGGER_CMD", "sudo systemctl start rag-indexer")
    subprocess.run(
        ["ssh", ssh_target, trigger_cmd],
        check=True,
    )

    return {
        "project": project_name,
        "source": str(src),
        "remote_path": f"{dest_dir}/{src.name}",
        "note": "Indexer triggered on NAS after upload.",
    }


if __name__ == "__main__":
    mcp.run()
