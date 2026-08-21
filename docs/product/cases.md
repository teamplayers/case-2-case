# Cases

A case is a ticket in one workspace: title, description, type, one category, optional tags, reporter, optional assignee, stage, optional audio path, conversation log, and an `ai` object.

## Case types

Each case has a `type` chosen at filing time from the workspace’s enabled types:

| Type | Value |
|------|-------|
| Complaint | `complaint` |
| Bug | `bug` |
| Feedback | `feedback` |
| Request | `request` |
| Ticket | `ticket` |

Workspaces enable or disable each type in Settings. At least one type must stay enabled.

## Create

- Path: `POST /api/cases`
- Body: `{ "workspaceId", "title", "description", "type", "category", "tags" }`
- Title: 1–200 characters
- `type` must be enabled on the workspace (400 otherwise)
- `category` must be one of the workspace categories (400 otherwise)
- Each tag must exist on the workspace (400 listing unknown tags)
- Agents may only create in workspaces they belong to
- Customers may create in any workspace
- Initial state: `stage: open`, `assigneeId: null`, `reporterId` = current user, `conversationLog: []`, empty AI fields

The new-case UI (`/cases/new`) loads workspaces, picks type and category from the selected workspace, toggles tags, and can attach a conversation audio file. Audio is uploaded in a second request after the case is created (`POST /api/cases/{id}/audio`).

## List

- Path: `GET /api/cases`
- Query: optional `workspaceId`, optional `stage`, optional `type`, optional `q` (search)
- Search (`q`) matches title, description, `ai.transcript`, `ai.translation`, and conversation log transcript/translation fields (case-insensitive)
- Visibility: [roles](roles.md)
- Newest first (`createdAt` descending)
- Each row includes `workspaceName`

UI `/cases` filters by workspace, stage, type, and search. Resolved is labeled **Closed**.

## Detail

- Path: `GET /api/cases/{id}`
- Adds `reporterName` and `assigneeName`
- Customer: 403 unless they are the reporter
- Agent: 403 unless they belong to the workspace

UI `/cases/:id` shows description, tags, people, triage (staff), conversation log, and AI output when present.

## Conversation log

When a conversation audio file is transcribed, an entry is appended to `conversationLog`:

```text
conversationLog[]:
  type            "transcription"
  transcript      raw Whisper output
  translation     English translation (if available)
  createdAt       timestamp
```

Any case type can attach conversation audio. See [conversation audio and AI](complaint-audio.md).

## What a case stores (AI)

```text
ai.status              queued | transcribing | translating | summarizing | categorizing | done | failed | null
ai.transcript
ai.translation
ai.summary
ai.suggestedCategory
ai.error
```

See [conversation audio and AI](complaint-audio.md).

## Related actions

- Assign: [assignment](assignment.md)
- Stage: [case workflow](case-workflow.md)
- Apply AI category: `POST /api/cases/{id}/apply-ai-category` (admin/agent) — sets `category` to `ai.suggestedCategory` if that value is still on the workspace
