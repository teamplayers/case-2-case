# Product

case2case is a workspace-based case desk. A **workspace** is a collection of cases plus configuration: name, categories, tags, and members. It has **no type**. Each **case** has a type (complaint, bug, feedback, request, or ticket). Cases start in **open** and move through assignment and work until **resolved** (shown as Closed).

Only an **SuperAdmin** or **DuperAdmin** can see all workspaces, edit workspace settings at the platform level, and add users. Other people only see spaces they belong to. Anyone with access to several workspaces switches from the top-right dropdown; workspace features live at `/wspace/<workspaceId>/app/…` and platform admin at `/cp/…`.

The product is aimed at mixed-language support intake. Optional call recordings on **any case type** are transcribed with Whisper, appended to the case conversation log, then sent to OpenAI for an English translation, a short summary, and a suggested category from that workspace’s list. Cases are searchable by transcript text.

## Who uses it

| Tier | Role | Typical work |
| --- | --- | --- |
| App | **DuperAdmin** (one) | Assign SuperAdmins; full platform control |
| App | **SuperAdmin** | Workspaces CRUD; user master; approve users; assign workspace Admin |
| Workspace | **Admin** | Categories, tags; add users with roles |
| Workspace | **Manager** | See all cases; add approved users; assign roles |
| Workspace | **Agent** | See assigned cases only |
| Workspace | **Customer** | File and track own cases |
| Workspace | **Guest** | Read-only access to all cases |

## How a case moves

1. Admin creates a workspace (config only) and adds members.
2. A member creates a case with a **type**, a workspace category, and optional tags.
3. On any case type, conversation audio can be uploaded at create time or from the case page.
4. Staff assign or take a case. Stage becomes **assigned** if it was still **open**.
5. Staff move **assigned → wip → resolved**. You cannot skip stages. Resolved cases cannot move further.
6. If AI suggested a category, staff can apply it.

## Feature index

| Feature | Spec |
| --- | --- |
| Authentication | [product/authentication.md](product/authentication.md) |
| Roles and visibility | [product/roles.md](product/roles.md) |
| User management | [product/users.md](product/users.md) |
| Workspaces | [product/workspaces.md](product/workspaces.md) |
| Cases | [product/cases.md](product/cases.md) |
| Case workflow | [product/case-workflow.md](product/case-workflow.md) |
| Assignment and triage | [product/assignment.md](product/assignment.md) |
| Conversation audio and AI | [product/complaint-audio.md](product/complaint-audio.md) |

## UI map

| Screen | Who | Purpose |
| --- | --- | --- |
| Sign in / Register | Public | Sign in or create a pending account |
| Change password | Signed in | Required after seeded or admin-created passwords |
| Control panel `/cp/*` | SuperAdmin / DuperAdmin | Workspaces, user master |
| Workspace picker `/wspace` | Signed in | Choose a workspace |
| Cases `/wspace/:id/app/cases` | Members | List and filter cases |
| New case | Members | File a case |
| Case detail | Members (scoped) | Detail, triage, conversation, AI |
| Workspace switcher | All signed-in pages | Top-right dropdown |
| Settings | Workspace Admin | Name, types, categories, tags |
| Users | Workspace Admin / Manager | Assign members and roles |
| You | Signed in | Account |

## Out of scope (current build)

- Reopening a resolved case
- Agents assigning cases to other people
- Customers seeing other customers’ cases
- Background job queue (audio runs as an in-process asyncio task on the API)
