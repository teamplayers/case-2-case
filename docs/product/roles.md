# Roles and visibility

Authorization has two tiers: **application roles** and **workspace roles**.

## Application roles

| Role | Scope | Capabilities |
| --- | --- | --- |
| **DuperAdmin** | Application (exactly one user) | Everything SuperAdmin can do; assign or revoke SuperAdmin |
| **SuperAdmin** | Application | Workspace CRUD; user master (approve, add, delete); assign workspace Admin |

Users without an application role are regular users. They access workspaces only through workspace membership.

## Workspace roles

Assigned per workspace via `members: [{ userId, role }]`.

| Role | Cases | Workspace |
| --- | --- | --- |
| **Admin** | See all; triage | Manage categories, tags; add users from user master |
| **Manager** | See all; triage | Add approved users; assign workspace roles (except Admin) |
| **Agent** | See assigned only; triage own cases | — |
| **Customer** | See own cases; create cases | — |
| **Guest** | See all (read-only) | — |

Only **SuperAdmin** can assign workspace **Admin**. Managers can assign Manager, Agent, Customer, Guest.

## User master

Every account stores:

```text
username | name | email | password (hash) | status | appRole
```

- **Sign up** creates a pending user (`status: pending`). They cannot sign in until approved.
- **SuperAdmin** approves, rejects, adds, or deletes users.
- **DuperAdmin** can promote users to SuperAdmin.

## Case visibility summary

| Workspace role | Cases visible |
| --- | --- |
| Admin, Manager, Guest | All in workspace |
| Agent | Assigned to them |
| Customer | Reported by them |
| SuperAdmin / DuperAdmin | All (application-wide) |

## APIs

- User master: `GET/PATCH/DELETE /api/users`, `GET /api/users/pending`, `POST /api/users/{id}/approve|reject`
- SuperAdmin assignment: `POST/DELETE /api/users/{id}/superadmin` (DuperAdmin only)
- Workspace members: `PATCH /api/workspaces/{id}` with `members: [{ userId, role }]`
