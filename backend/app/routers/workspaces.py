from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user, require_app_operators
from app.db import get_db
from app.models import WorkspaceCreateIn, WorkspaceMemberIn, WorkspaceUpdateIn, oid, utcnow
from app.permissions import (
    WORKSPACE_ROLES,
    can_assign_workspace_admin,
    can_manage_workspace_members,
    can_manage_workspace_settings,
    can_manage_workspaces,
    get_workspace_role,
    is_app_operator,
    is_workspace_member,
    serialize_members,
    workspace_member_query,
    workspace_members,
)
from app.workspace_config import (
    CASE_TYPES,
    normalize_case_types,
    normalize_categories,
    normalize_tags,
    normalize_workspace_fields,
)

router = APIRouter(prefix="/api/workspaces", tags=["workspaces"])


def is_member(user: dict, ws: dict) -> bool:
    return is_workspace_member(user, ws)


def _oids(ids: list[str]):
    return [oid(i) for i in ids]


def _normalize_members(raw: list[WorkspaceMemberIn], actor: dict) -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for item in raw:
        if item.userId in seen:
            continue
        if item.role not in WORKSPACE_ROLES:
            raise HTTPException(status_code=400, detail=f"Invalid workspace role: {item.role}")
        if item.role == "admin" and not can_assign_workspace_admin(actor):
            raise HTTPException(status_code=403, detail="Only SuperAdmin can assign workspace Admin")
        seen.add(item.userId)
        out.append({"userId": oid(item.userId), "role": item.role})
    return out


async def public_workspace(db, doc: dict, user: dict | None = None) -> dict[str, Any]:
    out = {
        "id": str(doc["_id"]),
        "name": doc.get("name"),
        "description": doc.get("description") or "",
        "createdAt": doc.get("createdAt"),
        "updatedAt": doc.get("updatedAt"),
    }
    fields = normalize_workspace_fields(doc)
    out.update(fields)
    out["members"] = serialize_members(doc)
    if user is not None:
        out["myRole"] = get_workspace_role(user, doc)
    return out


@router.get("")
async def list_workspaces(user: Annotated[dict, Depends(get_current_user)]):
    db = get_db()
    query: dict = {}
    if not is_app_operator(user):
        query = workspace_member_query(user["id"])
    rows = []
    async for doc in db.workspaces.find(query).sort("name", 1):
        rows.append(await public_workspace(db, doc, user))
    return rows


@router.post("")
async def create_workspace(
    body: WorkspaceCreateIn,
    user: Annotated[dict, Depends(require_app_operators())],
):
    db = get_db()
    members = [{"userId": oid(mid), "role": "admin"} for mid in body.memberIds]
    doc = {
        "name": body.name.strip(),
        "description": body.description.strip(),
        "caseTypes": {t: True for t in CASE_TYPES},
        "categories": [{"id": "general", "label": "General", "color": "#007AFF"}],
        "tags": [],
        "members": members,
        "createdAt": utcnow(),
    }
    result = await db.workspaces.insert_one(doc)
    created = await db.workspaces.find_one({"_id": result.inserted_id})
    return await public_workspace(db, created, user)


@router.get("/{workspace_id}")
async def get_workspace(
    workspace_id: str,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Workspace not found")
    if not is_member(user, doc):
        raise HTTPException(status_code=403, detail="Forbidden")
    return await public_workspace(db, doc, user)


@router.patch("/{workspace_id}")
async def update_workspace(
    workspace_id: str,
    body: WorkspaceUpdateIn,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    existing = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Workspace not found")
    if not is_member(user, existing):
        raise HTTPException(status_code=403, detail="Forbidden")

    patch: dict = {"updatedAt": utcnow()}
    if body.name is not None:
        if not can_manage_workspaces(user) and get_workspace_role(user, existing) != "admin":
            raise HTTPException(status_code=403, detail="Forbidden")
        patch["name"] = body.name.strip()
    if body.description is not None:
        if not can_manage_workspaces(user) and get_workspace_role(user, existing) != "admin":
            raise HTTPException(status_code=403, detail="Forbidden")
        patch["description"] = body.description.strip()
    if body.caseTypes is not None or body.categories is not None or body.tags is not None:
        if not can_manage_workspace_settings(user, existing):
            raise HTTPException(status_code=403, detail="Forbidden")
        if body.caseTypes is not None:
            patch["caseTypes"] = normalize_case_types(body.caseTypes)
        if body.categories is not None:
            patch["categories"] = normalize_categories([c.model_dump() for c in body.categories])
        if body.tags is not None:
            patch["tags"] = normalize_tags([t.model_dump() for t in body.tags])
    if body.members is not None:
        if not can_manage_workspace_members(user, existing):
            raise HTTPException(status_code=403, detail="Forbidden")
        db_users = get_db()
        for member in body.members:
            target = await db_users.users.find_one({"_id": oid(member.userId)})
            if not target:
                raise HTTPException(status_code=400, detail=f"Unknown user: {member.userId}")
            if target.get("status") != "approved" and not is_app_operator(user):
                raise HTTPException(status_code=400, detail=f"User not approved: {member.userId}")
        patch["members"] = _normalize_members(body.members, user)
    elif body.memberIds is not None:
        if not can_manage_workspace_members(user, existing):
            raise HTTPException(status_code=403, detail="Forbidden")
        patch["members"] = [{"userId": oid(i), "role": "customer"} for i in body.memberIds]

    await db.workspaces.update_one({"_id": existing["_id"]}, {"$set": patch})
    updated = await db.workspaces.find_one({"_id": existing["_id"]})
    return await public_workspace(db, updated, user)


@router.delete("/{workspace_id}")
async def delete_workspace(
    workspace_id: str,
    user: Annotated[dict, Depends(require_app_operators())],
):
    db = get_db()
    existing = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Workspace not found")
    await db.workspaces.delete_one({"_id": existing["_id"]})
    return {"ok": True}
