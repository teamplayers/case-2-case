from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user, hash_password, require_app_operators, require_duperadmin
from app.db import get_db
from app.models import UserCreateIn, UserUpdateIn, oid, utcnow
from app.permissions import (
    can_manage_usermaster,
    can_manage_workspace_members,
    is_app_operator,
    public_user,
)

router = APIRouter(prefix="/api/users", tags=["users"])


async def _get_workspace(db, workspace_id: str | None):
    if not workspace_id:
        return None
    return await db.workspaces.find_one({"_id": oid(workspace_id)})


@router.get("")
async def list_users(
    user: Annotated[dict, Depends(get_current_user)],
    workspaceId: str | None = None,
    approvedOnly: bool = True,
    q: str | None = None,
):
    db = get_db()
    ws = await _get_workspace(db, workspaceId)
    if workspaceId:
        if not ws:
            raise HTTPException(status_code=404, detail="Workspace not found")
        if not can_manage_workspace_members(user, ws) and not is_app_operator(user):
            raise HTTPException(status_code=403, detail="Forbidden")
    elif not can_manage_usermaster(user):
        raise HTTPException(status_code=403, detail="Forbidden")

    query: dict = {}
    if approvedOnly and not is_app_operator(user):
        query["status"] = "approved"
    elif approvedOnly:
        query["status"] = {"$in": ["approved", "pending", "rejected"]}
    if q and q.strip():
        pattern = {"$regex": q.strip(), "$options": "i"}
        query["$or"] = [{"username": pattern}, {"name": pattern}, {"email": pattern}]

    rows = []
    async for doc in db.users.find(query).sort("username", 1):
        rows.append(public_user(doc))
    return rows


@router.get("/pending")
async def list_pending(user: Annotated[dict, Depends(require_app_operators())]):
    db = get_db()
    rows = []
    async for doc in db.users.find({"status": "pending"}).sort("createdAt", -1):
        rows.append(public_user(doc))
    return rows


@router.post("")
async def create_user(
    body: UserCreateIn,
    user: Annotated[dict, Depends(require_app_operators())],
):
    db = get_db()
    username = body.username.strip()
    email = body.email.strip().lower()
    if await db.users.find_one({"username": username}):
        raise HTTPException(status_code=409, detail="Username already taken")
    if await db.users.find_one({"email": email}):
        raise HTTPException(status_code=409, detail="Email already registered")
    if body.appRole == "duperadmin":
        raise HTTPException(status_code=400, detail="Use assign-superadmin to manage DuperAdmin")
    if body.appRole == "superadmin" and not user.get("appRole") == "duperadmin":
        raise HTTPException(status_code=403, detail="Only DuperAdmin can create SuperAdmins")
    result = await db.users.insert_one(
        {
            "username": username,
            "name": body.name.strip(),
            "email": email,
            "passwordHash": hash_password(body.password),
            "appRole": body.appRole,
            "status": "approved",
            "mustChangePassword": True,
            "createdAt": utcnow(),
        }
    )
    doc = await db.users.find_one({"_id": result.inserted_id})
    return public_user(doc)


@router.patch("/{user_id}")
async def update_user(
    user_id: str,
    body: UserUpdateIn,
    actor: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    if not can_manage_usermaster(actor):
        raise HTTPException(status_code=403, detail="Forbidden")
    patch: dict = {"updatedAt": utcnow()}
    if body.name is not None:
        patch["name"] = body.name.strip()
    if body.email is not None:
        email = body.email.strip().lower()
        existing = await db.users.find_one({"email": email, "_id": {"$ne": doc["_id"]}})
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered")
        patch["email"] = email
    if body.status is not None:
        patch["status"] = body.status
    if body.appRole is not None:
        if body.appRole == "duperadmin":
            raise HTTPException(status_code=400, detail="Cannot assign DuperAdmin here")
        if body.appRole == "superadmin" and actor.get("appRole") != "duperadmin":
            raise HTTPException(status_code=403, detail="Only DuperAdmin can assign SuperAdmin")
        patch["appRole"] = body.appRole
    await db.users.update_one({"_id": doc["_id"]}, {"$set": patch})
    updated = await db.users.find_one({"_id": doc["_id"]})
    return public_user(updated)


@router.post("/{user_id}/approve")
async def approve_user(user_id: str, actor: Annotated[dict, Depends(require_app_operators())]):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    await db.users.update_one(
        {"_id": doc["_id"]},
        {"$set": {"status": "approved", "updatedAt": utcnow()}},
    )
    updated = await db.users.find_one({"_id": doc["_id"]})
    return public_user(updated)


@router.post("/{user_id}/reject")
async def reject_user(user_id: str, actor: Annotated[dict, Depends(require_app_operators())]):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    if doc.get("appRole") == "duperadmin":
        raise HTTPException(status_code=400, detail="Cannot reject DuperAdmin")
    await db.users.update_one(
        {"_id": doc["_id"]},
        {"$set": {"status": "rejected", "updatedAt": utcnow()}},
    )
    updated = await db.users.find_one({"_id": doc["_id"]})
    return public_user(updated)


@router.delete("/{user_id}")
async def delete_user(user_id: str, actor: Annotated[dict, Depends(require_app_operators())]):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    if doc.get("appRole") == "duperadmin":
        raise HTTPException(status_code=400, detail="Cannot delete DuperAdmin")
    if str(doc["_id"]) == actor["id"]:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    await db.users.delete_one({"_id": doc["_id"]})
    await db.workspaces.update_many({}, {"$pull": {"members": {"userId": doc["_id"]}}})
    return {"ok": True}


@router.post("/{user_id}/superadmin")
async def assign_superadmin(
    user_id: str,
    actor: Annotated[dict, Depends(require_duperadmin())],
):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    await db.users.update_one(
        {"_id": doc["_id"]},
        {"$set": {"appRole": "superadmin", "status": "approved", "updatedAt": utcnow()}},
    )
    updated = await db.users.find_one({"_id": doc["_id"]})
    return public_user(updated)


@router.delete("/{user_id}/superadmin")
async def revoke_superadmin(
    user_id: str,
    actor: Annotated[dict, Depends(require_duperadmin())],
):
    db = get_db()
    doc = await db.users.find_one({"_id": oid(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="User not found")
    if doc.get("appRole") == "duperadmin":
        raise HTTPException(status_code=400, detail="Cannot revoke DuperAdmin")
    await db.users.update_one(
        {"_id": doc["_id"]},
        {"$set": {"appRole": None, "updatedAt": utcnow()}},
    )
    updated = await db.users.find_one({"_id": doc["_id"]})
    return public_user(updated)
