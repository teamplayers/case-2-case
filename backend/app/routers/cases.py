from __future__ import annotations

import re
from pathlib import Path
from typing import Annotated

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.auth import get_current_user
from app.config import settings
from app.db import get_db
from app.models import (
    ALLOWED_TRANSITIONS,
    AUDIO_EXTS,
    CaseAssignIn,
    CaseCreateIn,
    CaseStageIn,
    oid,
    serialize,
    utcnow,
)
from app.permissions import (
    TRIAGE_WORKSPACE_ROLES,
    can_create_case,
    can_manage_workspaces,
    can_view_case,
    can_work_cases,
    get_workspace_role,
    is_app_operator,
    is_workspace_member,
    workspace_member_query,
    workspace_members,
)
from app.workspace_config import category_labels, find_category, find_tag, type_enabled
from app.worker import run_audio_job

router = APIRouter(prefix="/api/cases", tags=["cases"])


async def _workspace(db, workspace_id: str) -> dict:
    doc = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return doc


def _can_work(user: dict, ws: dict) -> bool:
    return can_work_cases(user, ws)


async def _visible_query(user: dict, workspace_id: str | None = None) -> dict:
    db = get_db()
    if is_app_operator(user):
        return {"workspaceId": oid(workspace_id)} if workspace_id else {}

    if workspace_id:
        ws = await _workspace(db, workspace_id)
        role = get_workspace_role(user, ws)
        if role is None:
            return {"_id": None}
        if role in ("admin", "manager", "guest"):
            return {"workspaceId": oid(workspace_id)}
        if role == "agent":
            return {"workspaceId": oid(workspace_id), "assigneeId": oid(user["id"])}
        return {"workspaceId": oid(workspace_id), "reporterId": oid(user["id"])}

    ws_ids = [w["_id"] async for w in db.workspaces.find(workspace_member_query(user["id"]), {"_id": 1})]
    if not ws_ids:
        return {"_id": None}

    ors = []
    for ws in [doc async for doc in db.workspaces.find({"_id": {"$in": ws_ids}})]:
        role = get_workspace_role(user, ws)
        wid = ws["_id"]
        if role in ("admin", "manager", "guest"):
            ors.append({"workspaceId": wid})
        elif role == "agent":
            ors.append({"workspaceId": wid, "assigneeId": oid(user["id"])})
        elif role == "customer":
            ors.append({"workspaceId": wid, "reporterId": oid(user["id"])})
    return {"$or": ors} if ors else {"_id": None}


def _enrich(case: dict, ws: dict | None) -> dict:
    out = serialize(case)
    assert out
    if not out.get("type") and ws:
        out["type"] = ws.get("type") or "request"
    if ws:
        out["workspaceName"] = ws.get("name")
        cat = find_category(ws, out.get("category") or "")
        if cat:
            out["category"] = cat["id"]
            out["categoryLabel"] = cat["label"]
            out["categoryColor"] = cat["color"]
        else:
            out["categoryLabel"] = out.get("category")
        tag_docs = [find_tag(ws, t) for t in (out.get("tags") or [])]
        out["tagLabels"] = [t["label"] if t else str(raw) for t, raw in zip(tag_docs, out.get("tags") or [])]
    return out


@router.get("")
async def list_cases(
    user: Annotated[dict, Depends(get_current_user)],
    workspaceId: str | None = None,
    stage: str | None = None,
    type: str | None = None,
    q: str | None = None,
):
    db = get_db()
    query = await _visible_query(user, workspaceId)
    if stage:
        query["stage"] = stage
    if type:
        query["type"] = type
    if q and q.strip():
        pattern = re.escape(q.strip())
        search_or = [
            {"title": {"$regex": pattern, "$options": "i"}},
            {"description": {"$regex": pattern, "$options": "i"}},
            {"ai.transcript": {"$regex": pattern, "$options": "i"}},
            {"ai.translation": {"$regex": pattern, "$options": "i"}},
            {"conversationLog.transcript": {"$regex": pattern, "$options": "i"}},
            {"conversationLog.translation": {"$regex": pattern, "$options": "i"}},
        ]
        if "$or" in query:
            query = {"$and": [query, {"$or": search_or}]}
        else:
            query["$or"] = search_or
    workspaces = {str(w["_id"]): w async for w in db.workspaces.find({})}
    rows = []
    async for doc in db.cases.find(query).sort("createdAt", -1):
        ws = workspaces.get(str(doc["workspaceId"]))
        rows.append(_enrich(doc, ws))
    return rows


@router.post("")
async def create_case(
    body: CaseCreateIn,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    ws = await _workspace(db, body.workspaceId)
    if not can_create_case(user, ws):
        raise HTTPException(status_code=403, detail="You are not allowed to create cases here")
    if not type_enabled(ws, body.type):
        raise HTTPException(status_code=400, detail="This case type is disabled in the workspace")
    cat = find_category(ws, body.category)
    if not cat:
        raise HTTPException(status_code=400, detail="Category must be one of the workspace categories")
    resolved_tags = []
    for t in body.tags:
        found = find_tag(ws, t)
        if not found:
            raise HTTPException(status_code=400, detail=f"Unknown tag: {t}")
        resolved_tags.append(found["id"])
    doc = {
        "workspaceId": ws["_id"],
        "title": body.title.strip(),
        "description": body.description.strip(),
        "type": body.type,
        "category": cat["id"],
        "tags": resolved_tags,
        "stage": "open",
        "assigneeId": None,
        "reporterId": oid(user["id"]),
        "audioPath": None,
        "conversationLog": [],
        "ai": {
            "status": None,
            "transcript": None,
            "translation": None,
            "summary": None,
            "suggestedCategory": None,
            "error": None,
        },
        "createdAt": utcnow(),
        "updatedAt": utcnow(),
    }
    result = await db.cases.insert_one(doc)
    created = await db.cases.find_one({"_id": result.inserted_id})
    return _enrich(created, ws)


@router.get("/{case_id}")
async def get_case(case_id: str, user: Annotated[dict, Depends(get_current_user)]):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if not can_view_case(user, ws, doc):
        raise HTTPException(status_code=403, detail="Forbidden")
    out = _enrich(doc, ws)
    reporter = await db.users.find_one({"_id": doc["reporterId"]})
    assignee = await db.users.find_one({"_id": doc["assigneeId"]}) if doc.get("assigneeId") else None
    out["reporterName"] = reporter["username"] if reporter else None
    out["assigneeName"] = assignee["username"] if assignee else None
    out["canWork"] = _can_work(user, ws)
    return out


def _assignee_has_role(ws: dict, assignee_id: str) -> bool:
    target = oid(assignee_id)
    for member in workspace_members(ws):
        mid = member["userId"] if isinstance(member["userId"], ObjectId) else oid(str(member["userId"]))
        if mid == target and member["role"] in TRIAGE_WORKSPACE_ROLES:
            return True
    return False


@router.post("/{case_id}/assign")
async def assign_case(
    case_id: str,
    body: CaseAssignIn,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if not _can_work(user, ws):
        raise HTTPException(status_code=403, detail="Not allowed to triage in this workspace")
    if not _assignee_has_role(ws, body.assigneeId) and not is_app_operator(user):
        raise HTTPException(status_code=400, detail="Assignee must be Admin, Manager, or Agent in this workspace")
    role = get_workspace_role(user, ws)
    if role == "agent" and body.assigneeId != user["id"]:
        raise HTTPException(status_code=403, detail="Agents can only assign cases to themselves")
    agent = await db.users.find_one({"_id": oid(body.assigneeId)})
    if not agent:
        raise HTTPException(status_code=400, detail="Assignee not found")
    stage = doc["stage"]
    if stage == "open":
        stage = "assigned"
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"assigneeId": agent["_id"], "stage": stage, "updatedAt": utcnow()}},
    )
    return await get_case(case_id, user)


@router.post("/{case_id}/stage")
async def set_stage(
    case_id: str,
    body: CaseStageIn,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if not _can_work(user, ws):
        raise HTTPException(status_code=403, detail="Not allowed to triage in this workspace")
    role = get_workspace_role(user, ws)
    if role == "agent" and str(doc.get("assigneeId")) != user["id"]:
        raise HTTPException(status_code=403, detail="Agents can only update assigned cases")
    current = doc["stage"]
    if body.stage != current and body.stage not in ALLOWED_TRANSITIONS.get(current, []):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot move from {current} to {body.stage}",
        )
    if body.stage == "assigned" and not doc.get("assigneeId"):
        raise HTTPException(status_code=400, detail="Assign an agent before moving to assigned")
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"stage": body.stage, "updatedAt": utcnow()}},
    )
    return await get_case(case_id, user)


@router.post("/{case_id}/apply-ai-category")
async def apply_ai_category(
    case_id: str,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if not _can_work(user, ws):
        raise HTTPException(status_code=403, detail="Not allowed to triage in this workspace")
    suggested = (doc.get("ai") or {}).get("suggestedCategory")
    if not suggested:
        raise HTTPException(status_code=400, detail="No AI category suggestion yet")
    cat = find_category(ws, suggested)
    if not cat:
        raise HTTPException(status_code=400, detail="Suggested category is not on this workspace")
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"category": cat["id"], "updatedAt": utcnow()}},
    )
    return await get_case(case_id, user)


def _enqueue(case_id: str, audio_path: str, categories: list[str]) -> None:
    import asyncio

    asyncio.create_task(run_audio_job(case_id, audio_path, categories))


@router.post("/{case_id}/audio")
async def upload_audio(
    case_id: str,
    user: Annotated[dict, Depends(get_current_user)],
    file: UploadFile = File(...),
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    role = get_workspace_role(user, ws)
    if role == "customer" and str(doc["reporterId"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Forbidden")
    if role == "agent" and not is_workspace_member(user, ws):
        raise HTTPException(status_code=403, detail="Forbidden")
    if role == "guest":
        raise HTTPException(status_code=403, detail="Guests cannot upload conversation")
    if role is None and not is_app_operator(user):
        raise HTTPException(status_code=403, detail="Forbidden")
    suffix = Path(file.filename or "audio").suffix.lower()
    if suffix not in AUDIO_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported audio type")
    dest_dir = settings.data_path / "uploads" / case_id
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / f"conversation{suffix}"
    dest.write_bytes(await file.read())
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {
            "$set": {
                "audioPath": str(dest),
                "ai.status": "queued",
                "ai.error": None,
                "updatedAt": utcnow(),
            }
        },
    )
    _enqueue(case_id, str(dest), category_labels(ws))
    return await get_case(case_id, user)


@router.post("/{case_id}/audio/retry")
async def retry_audio(
    case_id: str,
    user: Annotated[dict, Depends(get_current_user)],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc or not doc.get("audioPath"):
        raise HTTPException(status_code=400, detail="No audio to retry")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if not _can_work(user, ws):
        raise HTTPException(status_code=403, detail="Not allowed to triage in this workspace")
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"ai.status": "queued", "ai.error": None, "updatedAt": utcnow()}},
    )
    _enqueue(case_id, doc["audioPath"], category_labels(ws))
    return await get_case(case_id, user)
