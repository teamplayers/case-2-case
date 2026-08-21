from datetime import datetime, timezone
from typing import Any, Literal

from bson import ObjectId
from fastapi import HTTPException
from pydantic import BaseModel, Field


Role = Literal["admin", "agent", "customer"]  # legacy only
AppRole = Literal["duperadmin", "superadmin"]
WorkspaceRole = Literal["admin", "manager", "agent", "customer", "guest"]
UserStatus = Literal["pending", "approved", "rejected"]
CaseType = Literal["complaint", "bug", "feedback", "request", "ticket"]
Stage = Literal["open", "assigned", "wip", "resolved"]
AiStatus = Literal[
    "queued",
    "transcribing",
    "translating",
    "summarizing",
    "categorizing",
    "done",
    "failed",
]

ALLOWED_TRANSITIONS: dict[str, list[str]] = {
    "open": ["assigned"],
    "assigned": ["wip"],
    "wip": ["resolved"],
    "resolved": [],
}

AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".mp4", ".ogg", ".webm", ".aac", ".flac"}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def oid(value: str) -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(status_code=400, detail="Invalid id")
    return ObjectId(value)


def serialize(doc: dict[str, Any] | None) -> dict[str, Any] | None:
    if doc is None:
        return None
    out = dict(doc)
    out["id"] = str(out.pop("_id"))
    for key in ("workspaceId", "assigneeId", "reporterId", "workerId"):
        if key in out and out[key] is not None:
            out[key] = str(out[key])
    members = out.get("memberIds") or out.get("agentIds") or []
    out["memberIds"] = [str(i) for i in members]
    out.pop("agentIds", None)
    return out


class LoginIn(BaseModel):
    username: str
    password: str


class RegisterIn(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=200)
    password: str = Field(min_length=4, max_length=128)


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=4, max_length=128)


class UserCreateIn(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=200)
    password: str = Field(min_length=4, max_length=128)
    appRole: AppRole | None = None


class UserUpdateIn(BaseModel):
    name: str | None = None
    email: str | None = None
    appRole: AppRole | None = None
    status: UserStatus | None = None


class WorkspaceMemberIn(BaseModel):
    userId: str
    role: WorkspaceRole


class WorkspaceMembersIn(BaseModel):
    members: list[WorkspaceMemberIn]


class WorkspaceCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = ""
    memberIds: list[str] = Field(default_factory=list)


class CategoryIn(BaseModel):
    id: str | None = None
    label: str = Field(min_length=1, max_length=80)
    color: str = "#007AFF"


class TagIn(BaseModel):
    id: str | None = None
    label: str = Field(min_length=1, max_length=80)


class WorkspaceUpdateIn(BaseModel):
    name: str | None = None
    description: str | None = None
    caseTypes: dict[str, bool] | None = None
    categories: list[CategoryIn] | None = None
    tags: list[TagIn] | None = None
    members: list[WorkspaceMemberIn] | None = None
    memberIds: list[str] | None = None  # legacy


class CaseCreateIn(BaseModel):
    workspaceId: str
    title: str = Field(min_length=1, max_length=200)
    description: str = ""
    type: CaseType
    category: str
    tags: list[str] = Field(default_factory=list)


class CaseAssignIn(BaseModel):
    assigneeId: str


class CaseStageIn(BaseModel):
    stage: Stage
