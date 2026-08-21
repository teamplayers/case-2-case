from __future__ import annotations

from typing import Any, Literal

from bson import ObjectId

from app.models import oid

AppRole = Literal["duperadmin", "superadmin"]
WorkspaceRole = Literal["admin", "manager", "agent", "customer", "guest"]
UserStatus = Literal["pending", "approved", "rejected"]

APP_ROLES = ("duperadmin", "superadmin")
WORKSPACE_ROLES = ("admin", "manager", "agent", "customer", "guest")
STAFF_WORKSPACE_ROLES = ("admin", "manager", "agent")
TRIAGE_WORKSPACE_ROLES = ("admin", "manager", "agent")


def normalize_app_role(raw: Any) -> str | None:
    if raw in APP_ROLES:
        return raw
    if raw == "admin":
        return "superadmin"
    return None


def normalize_user_fields(doc: dict) -> dict[str, Any]:
    app_role = doc.get("appRole")
    if app_role is None and doc.get("role") == "admin":
        app_role = "superadmin"
    status = doc.get("status") or "approved"
    return {
        "name": (doc.get("name") or doc.get("username") or "").strip(),
        "email": (doc.get("email") or "").strip().lower(),
        "appRole": app_role if app_role in APP_ROLES else None,
        "status": status if status in ("pending", "approved", "rejected") else "approved",
    }


def public_user(doc: dict) -> dict[str, Any]:
    fields = normalize_user_fields(doc)
    return {
        "id": str(doc["_id"]),
        "username": doc["username"],
        "name": fields["name"],
        "email": fields["email"],
        "appRole": fields["appRole"],
        "status": fields["status"],
        "mustChangePassword": doc.get("mustChangePassword", False),
        "createdAt": doc.get("createdAt"),
    }


def is_duperadmin(user: dict) -> bool:
    return normalize_user_fields(user)["appRole"] == "duperadmin"


def is_superadmin(user: dict) -> bool:
    return normalize_user_fields(user)["appRole"] in APP_ROLES


def is_app_operator(user: dict) -> bool:
    return is_superadmin(user)


def workspace_members(ws: dict) -> list[dict[str, Any]]:
    raw = ws.get("members")
    if isinstance(raw, list) and raw:
        out: list[dict[str, Any]] = []
        for item in raw:
            if not isinstance(item, dict):
                continue
            uid = item.get("userId")
            role = item.get("role")
            if uid is None or role not in WORKSPACE_ROLES:
                continue
            out.append({"userId": uid, "role": role})
        if out:
            return out
    legacy = list(ws.get("memberIds") or ws.get("agentIds") or [])
    return [{"userId": uid, "role": "agent"} for uid in legacy]


def member_user_ids(ws: dict) -> list[ObjectId]:
    return [m["userId"] if isinstance(m["userId"], ObjectId) else oid(str(m["userId"])) for m in workspace_members(ws)]


def get_workspace_role(user: dict, ws: dict) -> str | None:
    if is_app_operator(user):
        return "admin"
    uid = oid(user["id"])
    for member in workspace_members(ws):
        mid = member["userId"] if isinstance(member["userId"], ObjectId) else oid(str(member["userId"]))
        if mid == uid:
            return member["role"]
    return None


def is_workspace_member(user: dict, ws: dict) -> bool:
    return get_workspace_role(user, ws) is not None or is_app_operator(user)


def can_manage_workspaces(user: dict) -> bool:
    return is_app_operator(user)


def can_manage_usermaster(user: dict) -> bool:
    return is_app_operator(user)


def can_assign_superadmin(user: dict) -> bool:
    return is_duperadmin(user)


def can_manage_workspace_settings(user: dict, ws: dict) -> bool:
    role = get_workspace_role(user, ws)
    return is_app_operator(user) or role == "admin"


def can_manage_workspace_members(user: dict, ws: dict) -> bool:
    role = get_workspace_role(user, ws)
    return is_app_operator(user) or role in ("admin", "manager")


def can_assign_workspace_admin(user: dict) -> bool:
    return is_app_operator(user)


def can_see_all_cases(user: dict, ws: dict) -> bool:
    role = get_workspace_role(user, ws)
    return is_app_operator(user) or role in ("admin", "manager", "guest")


def can_work_cases(user: dict, ws: dict) -> bool:
    role = get_workspace_role(user, ws)
    return is_app_operator(user) or role in TRIAGE_WORKSPACE_ROLES


def can_create_case(user: dict, ws: dict) -> bool:
    role = get_workspace_role(user, ws)
    return is_app_operator(user) or role in ("admin", "manager", "agent", "customer")


def can_view_case(user: dict, ws: dict, case: dict) -> bool:
    if is_app_operator(user):
        return True
    role = get_workspace_role(user, ws)
    if role is None:
        return False
    if role in ("admin", "manager", "guest"):
        return True
    if role == "agent":
        assignee = case.get("assigneeId")
        return assignee is not None and str(assignee) == user["id"]
    if role == "customer":
        return str(case.get("reporterId")) == user["id"]
    return False


def workspace_member_query(user_id: str) -> dict:
    uid = oid(user_id)
    return {
        "$or": [
            {"members.userId": uid},
            {"memberIds": uid},
            {"agentIds": uid},
        ]
    }


def serialize_members(ws: dict) -> list[dict[str, str]]:
    return [
        {"userId": str(m["userId"]), "role": m["role"]}
        for m in workspace_members(ws)
    ]
