# case2case

case2case is a small case-management app for support-style work: workspaces, staged cases, role-based access, and optional complaint-call audio processing.

Customers file cases (complaint, bug, feedback, or request) into workspaces. A workspace is a collection of cases plus configuration (allowed types, categories, tags, members). Only an admin sees every workspace, edits settings, and adds people. Members who belong to several spaces switch from the top of the app; `workspaceId` stays in the URL. On **complaint** cases, a recording can be transcribed locally with Whisper, then translated, summarized, and categorized with OpenAI.

## Stack

| Layer | Tech |
| --- | --- |
| API | FastAPI on port `8765` |
| UI | Flutter (web on port `8080`; also iOS / Android / macOS) |
| Database | MongoDB 7 |
| Auth | JWT (cookie `c2c_token` and `Authorization: Bearer`) |
| Audio | faster-whisper, then OpenAI chat completions |

## Documentation

- [Install and set up](docs/installation.md)
- [Product overview and feature index](docs/product.md)
- [Licensing (AGPL-3.0)](docs/licensing.md)
- [Commercial license](docs/commercial-license.md)

## Quick start

See [docs/installation.md](docs/installation.md) for prerequisites and environment variables. After `.env` exists:

```bash
docker compose up -d mongo
chmod +x run-api.sh run-ui.sh
./run-api.sh                  # http://127.0.0.1:8765
./run-ui.sh                   # Flutter web at http://127.0.0.1:8080
```

Default login: **duperadmin** / **duperadmin**. You will be asked to change the password.

## Roles (short)

- **Admin** — users, all workspaces, settings (types/categories/tags), membership; all cases
- **Agent** — workspaces they belong to; switch among them; triage cases there
- **Customer** — workspaces they were added to; create cases; optional audio on complaint cases

Case stages: `open` → `assigned` → `wip` → `resolved` (shown as resolved/closed).

## License

case2case is licensed under [AGPL-3.0](LICENSE). Open-source use (including by commercial companies) is free if you comply with the license. Closed-source use requires a [commercial license](docs/commercial-license.md). See [docs/licensing.md](docs/licensing.md) for details.
