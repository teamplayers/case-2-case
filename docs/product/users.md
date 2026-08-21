# Users (user master)

The **user master** is the global list of accounts. Fields:

| Field | Notes |
| --- | --- |
| `username` | Unique login id (2–64 chars) |
| `name` | Display name |
| `email` | Unique email |
| `password` | Stored as bcrypt hash |
| `status` | `pending` \| `approved` \| `rejected` |
| `appRole` | `duperadmin` \| `superadmin` \| null |
| `mustChangePassword` | true for admin-created accounts |

## Sign up

- Path: `POST /api/auth/register`
- Body: `{ username, name, email, password }`
- Creates `status: pending`, `appRole: null`
- Does **not** sign the user in
- UI shows “pending approval” message

## Login

- Path: `POST /api/auth/login`
- 403 if `status != approved`

## User master APIs (SuperAdmin / DuperAdmin)

| Method | Path | Who |
| --- | --- | --- |
| `GET` | `/api/users` | SuperAdmin (all users); workspace Admin/Manager with `workspaceId` (approved users for picker) |
| `GET` | `/api/users/pending` | SuperAdmin |
| `POST` | `/api/users` | SuperAdmin — create approved user |
| `PATCH` | `/api/users/{id}` | SuperAdmin — update name, email, status, appRole |
| `POST` | `/api/users/{id}/approve` | SuperAdmin |
| `POST` | `/api/users/{id}/reject` | SuperAdmin |
| `DELETE` | `/api/users/{id}` | SuperAdmin |
| `POST` | `/api/users/{id}/superadmin` | DuperAdmin — grant SuperAdmin |
| `DELETE` | `/api/users/{id}/superadmin` | DuperAdmin — revoke SuperAdmin |

## Workspace membership

Users are added to workspaces with a workspace role:

```json
{ "members": [{ "userId": "...", "role": "manager" }] }
```

- **SuperAdmin** assigns workspace **Admin**
- **Workspace Admin** adds users, manages categories/tags
- **Workspace Manager** adds approved users and assigns roles (not Admin)

UI: `/wspace/:workspaceId/app/users` — members list with role dropdown; add from searchable user master.

Platform UI: `/cp/users` — pending queue, approve/reject, SuperAdmin promotion (DuperAdmin).

## Bootstrap

On first API start, if no DuperAdmin exists, user `duperadmin` / `duperadmin` is created as **DuperAdmin** with `mustChangePassword: true`.
