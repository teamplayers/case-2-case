from __future__ import annotations

import re
from typing import Any

CASE_TYPES = ("complaint", "bug", "feedback", "request", "ticket")
DEFAULT_COLORS = ("#007AFF", "#FF9500", "#FF3B30", "#34C759", "#5856D6", "#5AC8FA", "#AF52DE", "#8E8E93")


def slug_id(label: str, fallback: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (label or "").strip().lower()).strip("-")
    return s or fallback


def _as_list(raw: Any) -> list:
    return list(raw) if isinstance(raw, list) else []


def normalize_categories(raw: Any) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    seen: set[str] = set()
    for i, item in enumerate(_as_list(raw)):
        if isinstance(item, str):
            label = item.strip()
            cid = slug_id(label, f"cat-{i}")
            color = DEFAULT_COLORS[i % len(DEFAULT_COLORS)]
        elif isinstance(item, dict):
            label = str(item.get("label") or item.get("name") or "").strip()
            if not label:
                continue
            cid = str(item.get("id") or slug_id(label, f"cat-{i}"))
            color = str(item.get("color") or DEFAULT_COLORS[i % len(DEFAULT_COLORS)])
        else:
            continue
        if not label or cid in seen:
            continue
        seen.add(cid)
        out.append({"id": cid, "label": label, "color": color})
    return out


def normalize_tags(raw: Any) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    seen: set[str] = set()
    for i, item in enumerate(_as_list(raw)):
        if isinstance(item, str):
            label = item.strip()
            tid = slug_id(label, f"tag-{i}")
        elif isinstance(item, dict):
            label = str(item.get("label") or item.get("name") or "").strip()
            if not label:
                continue
            tid = str(item.get("id") or slug_id(label, f"tag-{i}"))
        else:
            continue
        if not label or tid in seen:
            continue
        seen.add(tid)
        out.append({"id": tid, "label": label})
    return out


def normalize_case_types(raw: Any) -> dict[str, bool]:
    enabled = {t: True for t in CASE_TYPES}
    if isinstance(raw, dict):
        for t in CASE_TYPES:
            if t in raw:
                enabled[t] = bool(raw[t])
    elif isinstance(raw, list):
        enabled = {t: t in raw for t in CASE_TYPES}
    if not any(enabled.values()):
        enabled["ticket"] = True
    return enabled


def normalize_workspace_fields(doc: dict) -> dict:
    return {
        "categories": normalize_categories(doc.get("categories")),
        "tags": normalize_tags(doc.get("tags")),
        "caseTypes": normalize_case_types(doc.get("caseTypes") or doc.get("case_types")),
    }


def category_labels(ws: dict) -> list[str]:
    return [c["label"] for c in normalize_categories(ws.get("categories"))]


def find_category(ws: dict, value: str) -> dict[str, str] | None:
    value = (value or "").strip()
    for c in normalize_categories(ws.get("categories")):
        if c["id"] == value or c["label"] == value:
            return c
    return None


def find_tag(ws: dict, value: str) -> dict[str, str] | None:
    value = (value or "").strip()
    for t in normalize_tags(ws.get("tags")):
        if t["id"] == value or t["label"] == value:
            return t
    return None


def type_enabled(ws: dict, case_type: str) -> bool:
    return bool(normalize_case_types(ws.get("caseTypes")).get(case_type))
