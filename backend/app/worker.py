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

        _whisper_model = WhisperModel(settings.whisper_model, device="auto", compute_type="auto")
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


def translate_and_analyze(transcript: str, categories: list[str]) -> dict:
    client = _openai()
    cats = categories or ["uncategorized"]
    prompt = (
        "You are helping a support case desk. The transcript may be Arabic, English, or mixed "
        "(including Indian English).\n"
        "Return JSON with keys: translation (English), summary (short bullets as one string), "
        "suggestedCategory (exactly one value from the provided list).\n"
        f"Categories: {json.dumps(cats)}\n\n"
        f"Transcript:\n{transcript}"
    )
    resp = client.chat.completions.create(
        model=settings.openai_model,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": "Return only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    data = json.loads(resp.choices[0].message.content or "{}")
    suggested = data.get("suggestedCategory") or cats[0]
    if suggested not in cats:
        suggested = cats[0]
    return {
        "translation": data.get("translation") or "",
        "summary": data.get("summary") or "",
        "suggestedCategory": suggested,
    }


async def set_ai(case_id: str, **fields) -> None:
    db = get_db()
    patch = {f"ai.{k}": v for k, v in fields.items()}
    patch["updatedAt"] = utcnow()
    await db.cases.update_one({"_id": oid(case_id)}, {"$set": patch})


async def run_audio_job(case_id: str, audio_path: str, categories: list[str]) -> None:
    try:
        await set_ai(case_id, status="transcribing", error=None)
        transcript = transcribe_file(Path(audio_path))
        await set_ai(case_id, transcript=transcript, status="translating")
        await set_ai(case_id, status="summarizing")
        await set_ai(case_id, status="categorizing")
        result = translate_and_analyze(transcript, categories)
        await set_ai(
            case_id,
            status="done",
            translation=result["translation"],
            summary=result["summary"],
            suggestedCategory=result["suggestedCategory"],
            error=None,
        )
    except Exception as exc:  # noqa: BLE001 — persist any pipeline failure
        await set_ai(case_id, status="failed", error=str(exc))
