# Case workflow

Cases use a one-way stage pipeline. The UI shows `resolved` as **resolved/closed**.

## Stages

| Stage | Meaning |
| --- | --- |
| `open` | Filed, not assigned |
| `assigned` | Has an assignee (required to enter this stage via the stage API) |
| `wip` | In progress |
| `resolved` | Done; no further transitions |

## Allowed transitions

```text
open      → assigned
assigned  → wip
wip       → resolved
resolved  → (none)
```

Any other jump (including skip or reverse) returns 400: `Cannot move from {current} to {target}`.

## Stage API

- Path: `POST /api/cases/{id}/stage`
- Body: `{ "stage" }`
- Admin or agent (agent must belong to the workspace)
- Moving to `assigned` without `assigneeId` returns 400: assign an agent first

Assigning a case from **open** also sets stage to **assigned** in the same write (see [assignment](assignment.md)). That is the usual way a case leaves `open`. Staff can then click through **wip** and **resolved** on the case page.

## UI

Case detail exposes a single “next stage” action using `open → assigned → wip → resolved`. There is no control to pick an arbitrary stage in the UI; the API still enforces the table above if called directly.
