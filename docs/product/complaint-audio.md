# Conversation audio and AI

Any case type can attach a recording of a customer conversation. The API transcribes it locally, appends the transcript to the case’s conversation log, then (if configured) asks OpenAI for an English translation, a short summary, and one suggested category from the workspace list.

## When audio is allowed

- Any case type (Complaint, Bug, Feedback, Request, Ticket)
- Customer: only on cases they reported
- Agent: only on cases in a workspace they belong to
- Admin: any case

## Upload

- Path: `POST /api/cases/{id}/audio`
- Multipart field: `file`
- Allowed extensions: `.mp3`, `.wav`, `.m4a`, `.mp4`, `.ogg`, `.webm`, `.aac`, `.flac`
- Stored as `{DATA_DIR}/uploads/{case-id}/conversation{ext}`
- Sets `audioPath`, `ai.status` to `queued`, clears `ai.error`
- Starts `run_audio_job` as an asyncio task on the API process (not a separate worker)

The new-case form can upload immediately after create. Case detail can upload or replace later (same filename pattern).

## Pipeline

Statuses, in order:

1. `queued` — accepted
2. `transcribing` — faster-whisper (`WHISPER_MODEL`); language auto-detect; VAD on; prompt assumes customer support in Arabic and English (including Indian English)
3. `translating` / `summarizing` / `categorizing` — one OpenAI JSON completion covering all three outputs
4. `done` — `transcript`, `translation`, `summary`, `suggestedCategory` stored; conversation log entry appended
5. `failed` — `ai.error` is the exception string

Whisper tries CUDA `float16`, then CPU `int8`. The OpenAI step requires `OPENAI_API_KEY` and returns JSON: `translation`, `summary`, `suggestedCategory`. If the suggested category is not in the workspace list, the first workspace category is used.

## Conversation log

On success, the pipeline appends to `conversationLog`:

```json
{
  "type": "transcription",
  "transcript": "...",
  "translation": "...",
  "createdAt": "..."
}
```

Cases are searchable by transcript and translation text via `GET /api/cases?q=...`.

## Retry

- Path: `POST /api/cases/{id}/audio/retry`
- Admin or agent
- Requires an existing `audioPath` (400 if none)
- Re-queues the same file

## Apply suggested category

- Path: `POST /api/cases/{id}/apply-ai-category`
- Admin or agent
- 400 if there is no suggestion, or if the suggestion is no longer on the workspace
- Overwrites `category`; does not change tags or description

## UI

While `ai.status` is an in-progress value, case detail polls about every 2.5 seconds. Staff can retry on failure and apply the suggested category when status is `done`. Transcribed text appears under **Conversation log** on the case detail screen.
