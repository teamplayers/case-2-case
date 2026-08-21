from __future__ import annotations

import json
from pathlib import Path

from openai import OpenAI

from app.config import settings
from app.db import get_db
from app.models import oid, utcnow

_whisper_model = None


def _whisper():
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel

        try:
            _whisper_model = WhisperModel(settings.whisper_model, device="cuda", compute_type="float16")
        except Exception:
            _whisper_model = WhisperModel(settings.whisper_model, device="cpu", compute_type="int8")
    return _whisper_model


def transcribe_file(path: Path) -> str:
    model = _whisper()
    segments, _info = model.transcribe(
        str(path),
        vad_filter=True,
        language=None,
        initial_prompt="Customer support call. Arabic and English, including Indian English accents.",
    )
    parts = [seg.text.strip() for seg in segments if seg.text.strip()]
    return "\n".join(parts)


def _openai() -> OpenAI:
    if not settings.openai_api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")
    return OpenAI(api_key=settings.openai_api_key)


def _chat_json(client: OpenAI, prompt: str) -> dict:
    resp = client.chat.completions.create(
        model=settings.openai_model,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": "Return only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    return json.loads(resp.choices[0].message.content or "{}")


def translate_text(transcript: str) -> str:
    data = _chat_json(
        _openai(),
        "Translate this support-call transcript to English. Keep names. "
        "Return JSON {\"translation\": \"...\"}.\n\n" + transcript,
    )
    return data.get("translation") or ""


def summarize_text(english: str) -> str:
    data = _chat_json(
        _openai(),
        "Summarize this support case in short English bullets as one string. "
        "Return JSON {\"summary\": \"...\"}.\n\n" + english,
    )
    return data.get("summary") or ""


def categorize_text(english: str, categories: list[str]) -> str:
    cats = categories or ["uncategorized"]
    data = _chat_json(
        _openai(),
        "Pick exactly one category for this support case from the list. "
        f"Return JSON {{\"suggestedCategory\": \"...\"}}.\nCategories: {json.dumps(cats)}\n\n{english}",
    )
    suggested = data.get("suggestedCategory") or cats[0]
    return suggested if suggested in cats else cats[0]


async def set_ai(case_id: str, **fields) -> None:
    db = get_db()
    patch = {f"ai.{k}": v for k, v in fields.items()}
    patch["updatedAt"] = utcnow()
    await db.cases.update_one({"_id": oid(case_id)}, {"$set": patch})


async def append_conversation_log(
    case_id: str,
    *,
    transcript: str,
    translation: str | None = None,
) -> None:
    db = get_db()
    entry = {
        "type": "transcription",
        "transcript": transcript,
        "translation": translation,
        "createdAt": utcnow(),
    }
    await db.cases.update_one(
        {"_id": oid(case_id)},
        {"$push": {"conversationLog": entry}, "$set": {"updatedAt": utcnow()}},
    )


async def run_audio_job(case_id: str, audio_path: str, categories: list[str]) -> None:
    try:
        await set_ai(case_id, status="transcribing", error=None)
        transcript = transcribe_file(Path(audio_path))
        await set_ai(case_id, transcript=transcript, status="translating")
        translation = translate_text(transcript)
        await set_ai(case_id, translation=translation, status="summarizing")
        summary = summarize_text(translation or transcript)
        await set_ai(case_id, summary=summary, status="categorizing")
        suggested = categorize_text(translation or transcript, categories)
        await set_ai(
            case_id,
            status="done",
            suggestedCategory=suggested,
            error=None,
        )
        await append_conversation_log(
            case_id,
            transcript=transcript,
            translation=translation or None,
        )
    except Exception as exc:  # noqa: BLE001 — persist any pipeline failure
        await set_ai(case_id, status="failed", error=str(exc))
