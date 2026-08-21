# Authentication

## Sign in

- Path: `POST /api/auth/login`
- Body: `{ username, password }`
- Sets httponly cookie `c2c_token` (7 days) and returns `{ token, user }`
- User object: `{ id, username, name, email, appRole, status, mustChangePassword }`
- 403 if account is not approved

## Sign up

- Path: `POST /api/auth/register`
- Body: `{ username, name, email, password }`
- Creates a **pending** user in the user master
- Returns `{ ok, status: "pending", message }` — no token

## Session

- Path: `GET /api/auth/me` — current user (requires auth)
- Path: `POST /api/auth/logout` — clears cookie

## Change password

- Path: `POST /api/auth/change-password`
- Body: `{ current_password, new_password }`
- Router forces `/change-password` when `mustChangePassword` is true

## JWT

Payload: `{ sub, appRole, exp }`. Workspace roles are resolved from membership on each request, not stored in the token.

## UI

| Route | Purpose |
| --- | --- |
| `/login` | Sign in |
| `/register` | Sign up (username, name, email, password) |
| `/change-password` | Required password change gate |

First boot: DuperAdmin `duperadmin` / `duperadmin`.
