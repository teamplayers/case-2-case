from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user, require_roles
from app.db import get_db
from app.models import WorkspaceCreateIn, WorkspaceUpdateIn, oid, serialize, utcnow

router = APIRouter(prefix="/api/workspaces", tags=["workspaces"])


def _agent_oids(ids: list[str]):
    return [oid(i) for i in ids]


@router.get("")
async def list_workspaces(user: Annotated[dict, Depends(get_current_user)]):
    db = get_db()
    query: dict = {}
    if user["role"] == "agent":
        query = {"agentIds": oid(user["id"])}
    rows = []
    async for doc in db.workspaces.find(query).sort("name", 1):
        rows.append(serialize(doc))
    return rows


@router.post("")
async def create_workspace(
    body: WorkspaceCreateIn,
    _: Annotated[dict, Depends(require_roles("admin"))],
):
    db = get_db()
    doc = {
        "name": body.name.strip(),
        "type": body.type,
        "categories": [c.strip() for c in body.categories if c.strip()],
        "tags": [t.strip() for t in body.tags if t.strip()],
        "agentIds": _agent_oids(body.agentIds),
        "createdAt": utcnow(),
    }
    result = await db.workspaces.insert_one(doc)
    created = await db.workspaces.find_one({"_id": result.inserted_id})
    return serialize(created)


@router.get("/{workspace_id}")
async def get_workspace(
    workspace_id: str,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Workspace not found")
    if user["role"] == "agent" and oid(user["id"]) not in doc.get("agentIds", []):
        raise HTTPException(status_code=403, detail="Forbidden")
    return serialize(doc)


@router.patch("/{workspace_id}")
async def update_workspace(
    workspace_id: str,
    body: WorkspaceUpdateIn,
    _: Annotated[dict, Depends(require_roles("admin"))],
):
    db = get_db()
    existing = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Workspace not found")
    patch: dict = {"updatedAt": utcnow()}
    if body.name is not None:
        patch["name"] = body.name.strip()
    if body.categories is not None:
        patch["categories"] = [c.strip() for c in body.categories if c.strip()]
    if body.tags is not None:
        patch["tags"] = [t.strip() for t in body.tags if t.strip()]
    if body.agentIds is not None:
        patch["agentIds"] = _agent_oids(body.agentIds)
    await db.workspaces.update_one({"_id": existing["_id"]}, {"$set": patch})
    return serialize(await db.workspaces.find_one({"_id": existing["_id"]}))
