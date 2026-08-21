# Assignment and triage

Triage lives on the case detail page for **admin** and **agent**. Customers see reporter and assignee names but cannot change them.

## Assign API

- Path: `POST /api/cases/{id}/assign`
- Body: `{ "assigneeId" }`
- Assignee must be a user with role **agent** or **admin** (400 otherwise)
- **Admin** may assign to any such user
- **Agent** may assign only to themselves (403 otherwise)
- Agent must belong to the case’s workspace
- If the case is `open`, stage is set to `assigned` in the same update
- If the case is already past `open`, assignee is updated and stage is left as-is

## UI behavior

- Admin: dropdown of agents and admins, then submit
- Agent: a take-the-case action that posts their own id (no picking another person)

## Typical path

1. Customer files a case (`open`, unassigned)
2. Admin assigns an agent, or the agent takes it → `assigned`
3. Staff advance to `wip`, then `resolved` ([workflow](case-workflow.md))

There is no unassign API. Setting a new assignee replaces the previous one.
