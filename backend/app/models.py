from datetime import datetime, timezone
from typing import Any, Literal

from bson import ObjectId
from pydantic import BaseModel, Field


Role = Literal["admin", "agent", "customer"]
WorkspaceType = Literal["complaint", "bug", "feedback", "request"]
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
        raise ValueError("Invalid id")
    return ObjectId(value)


def serialize(doc: dict[str, Any] | None) -> dict[str, Any] | None:
    if doc is None:
        return None
    out = dict(doc)
    out["id"] = str(out.pop("_id"))
    for key in ("workspaceId", "assigneeId", "reporterId"):
        if key in out and out[key] is not None:
            out[key] = str(out[key])
    if "agentIds" in out:
        out["agentIds"] = [str(i) for i in out["agentIds"]]
    return out


class LoginIn(BaseModel):
    username: str
    password: str


class RegisterIn(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=4, max_length=128)


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=4, max_length=128)


class UserCreateIn(BaseModel):
    username: str = Field(min_length=2, max_length=64)
    password: str = Field(min_length=4, max_length=128)
    role: Role


class WorkspaceCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: WorkspaceType
    categories: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    agentIds: list[str] = Field(default_factory=list)


class WorkspaceUpdateIn(BaseModel):
    name: str | None = None
    categories: list[str] | None = None
    tags: list[str] | None = None
    agentIds: list[str] | None = None


class CaseCreateIn(BaseModel):
    workspaceId: str
    title: str = Field(min_length=1, max_length=200)
    description: str = ""
    category: str
    tags: list[str] = Field(default_factory=list)


class CaseAssignIn(BaseModel):
    assigneeId: str


class CaseStageIn(BaseModel):
    stage: Stage
