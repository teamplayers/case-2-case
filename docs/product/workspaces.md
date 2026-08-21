# Workspaces

A workspace is a **collection of cases** plus configuration. It has no type. Case types, categories, and tags are settings on the workspace. Multiple members can access several workspaces and switch from the top-right dropdown on any page; the active workspace id is in workspace URLs: `/wspace/<workspaceId>/app/…`.

Only an **admin** can see every workspace and add users to it. **SuperAdmin / DuperAdmin** manage workspaces at `/cp/workspace`.

## Configuration

- `name` / `description`
- `caseTypes` — map of `complaint` | `bug` | `feedback` | `request` | `ticket` to enabled/disabled
- `categories` — `{id, label, color}` (cases pick one)
- `tags` — `{id, label}` (cases may pick several)
- `memberIds` — users who may enter the workspace

Legacy string categories/tags and old `agentIds` are normalized when read.

## APIs

| Method | Path | Who |
| --- | --- | --- |
| `GET` | `/api/workspaces` | Signed in. Non-admin: membership only |
| `POST` | `/api/workspaces` | Admin |
| `GET` | `/api/workspaces/{id}` | Member or admin |
| `PATCH` | `/api/workspaces/{id}` | Admin. Body may include `name`, `description`, `caseTypes`, `categories`, `tags`, `memberIds` |

## UI (browser)

| Path | Who |
| --- | --- |
| `/cp/workspace` | SuperAdmin / DuperAdmin — workspace management |
| `/cp/users` | SuperAdmin / DuperAdmin — user master |
| `/wspace` | Workspace picker |
| `/wspace/<id>/app/cases` | Members |
| `/wspace/<id>/app/cases/new` | Members |
| `/wspace/<id>/app/cases/<caseId>` | Members |
| `/wspace/<id>/app/users` | Workspace Admin / Manager |
| `/wspace/<id>/app/settings` | Workspace Admin |
| `/wspace/<id>/app/you` | Signed in |

Switch workspace from the top control; the rest of the path is kept (`/users` stays `/users`).
