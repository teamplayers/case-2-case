from __future__ import annotations

from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.auth import get_current_user, require_roles
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
from app.worker import run_audio_job

router = APIRouter(prefix="/api/cases", tags=["cases"])


async def _workspace(db, workspace_id: str) -> dict:
    doc = await db.workspaces.find_one({"_id": oid(workspace_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return doc


def _can_see_workspace(user: dict, ws: dict) -> bool:
    if user["role"] == "admin":
        return True
    if user["role"] == "agent":
        return oid(user["id"]) in ws.get("agentIds", [])
    return True


async def _visible_query(user: dict) -> dict:
    db = get_db()
    if user["role"] == "admin":
        return {}
    if user["role"] == "customer":
        return {"reporterId": oid(user["id"])}
    ws_ids = [w["_id"] async for w in db.workspaces.find({"agentIds": oid(user["id"])}, {"_id": 1})]
    return {"workspaceId": {"$in": ws_ids}}


def _enrich(case: dict, ws: dict | None) -> dict:
    out = serialize(case)
    assert out
    if ws:
        out["workspaceName"] = ws.get("name")
        out["workspaceType"] = ws.get("type")
    return out


@router.get("")
async def list_cases(
    user: Annotated[dict, Depends(get_current_user)],
    workspaceId: str | None = None,
    stage: str | None = None,
):
    db = get_db()
    query = await _visible_query(user)
    if workspaceId:
        query["workspaceId"] = oid(workspaceId)
    if stage:
        query["stage"] = stage
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
    if user["role"] == "agent" and not _can_see_workspace(user, ws):
        raise HTTPException(status_code=403, detail="Forbidden")
    cats = ws.get("categories") or []
    tags = ws.get("tags") or []
    if body.category not in cats:
        raise HTTPException(status_code=400, detail="Category must be one of the workspace categories")
    bad = [t for t in body.tags if t not in tags]
    if bad:
        raise HTTPException(status_code=400, detail=f"Unknown tags: {', '.join(bad)}")
    doc = {
        "workspaceId": ws["_id"],
        "title": body.title.strip(),
        "description": body.description.strip(),
        "category": body.category,
        "tags": body.tags,
        "stage": "open",
        "assigneeId": None,
        "reporterId": oid(user["id"]),
        "audioPath": None,
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
    if user["role"] == "customer" and str(doc["reporterId"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Forbidden")
    if user["role"] == "agent" and not _can_see_workspace(user, ws):
        raise HTTPException(status_code=403, detail="Forbidden")
    out = _enrich(doc, ws)
    reporter = await db.users.find_one({"_id": doc["reporterId"]})
    assignee = await db.users.find_one({"_id": doc["assigneeId"]}) if doc.get("assigneeId") else None
    out["reporterName"] = reporter["username"] if reporter else None
    out["assigneeName"] = assignee["username"] if assignee else None
    return out


@router.post("/{case_id}/assign")
async def assign_case(
    case_id: str,
    body: CaseAssignIn,
    user: Annotated[dict, Depends(require_roles("admin", "agent"))],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if user["role"] == "agent" and not _can_see_workspace(user, ws):
        raise HTTPException(status_code=403, detail="Forbidden")
    agent = await db.users.find_one({"_id": oid(body.assigneeId), "role": {"$in": ["agent", "admin"]}})
    if not agent:
        raise HTTPException(status_code=400, detail="Assignee must be an agent or admin")
    if user["role"] == "agent" and str(agent["_id"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Agents can only assign cases to themselves")
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
    user: Annotated[dict, Depends(require_roles("admin", "agent"))],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    if user["role"] == "agent" and not _can_see_workspace(user, ws):
        raise HTTPException(status_code=403, detail="Forbidden")
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
    user: Annotated[dict, Depends(require_roles("admin", "agent"))],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Case not found")
    ws = await _workspace(db, str(doc["workspaceId"]))
    suggested = (doc.get("ai") or {}).get("suggestedCategory")
    if not suggested:
        raise HTTPException(status_code=400, detail="No AI category suggestion yet")
    if suggested not in (ws.get("categories") or []):
        raise HTTPException(status_code=400, detail="Suggested category is not on this workspace")
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"category": suggested, "updatedAt": utcnow()}},
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
    if ws.get("type") != "complaint":
        raise HTTPException(status_code=400, detail="Audio is only allowed on complaint workspaces")
    if user["role"] == "customer" and str(doc["reporterId"]) != user["id"]:
        raise HTTPException(status_code=403, detail="Forbidden")
    if user["role"] == "agent" and not _can_see_workspace(user, ws):
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
    _enqueue(case_id, str(dest), ws.get("categories") or [])
    return await get_case(case_id, user)


@router.post("/{case_id}/audio/retry")
async def retry_audio(
    case_id: str,
    user: Annotated[dict, Depends(require_roles("admin", "agent"))],
):
    db = get_db()
    doc = await db.cases.find_one({"_id": oid(case_id)})
    if not doc or not doc.get("audioPath"):
        raise HTTPException(status_code=400, detail="No audio to retry")
    ws = await _workspace(db, str(doc["workspaceId"]))
    await db.cases.update_one(
        {"_id": doc["_id"]},
        {"$set": {"ai.status": "queued", "ai.error": None, "updatedAt": utcnow()}},
    )
    _enqueue(case_id, doc["audioPath"], ws.get("categories") or [])
    return await get_case(case_id, user)
