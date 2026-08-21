# Install and set up

This guide gets a local case2case instance running: MongoDB, the FastAPI backend, and the Flutter UI.

## Prerequisites

- **Python 3.10+**
- **Flutter** (SDK 3.16+; `flutter` on `PATH`)
- **Docker** (used only to run MongoDB)
- **ffmpeg** on `PATH` (required by Whisper for audio)
- An **OpenAI API key** if you want translate / summarize / categorize after transcription (optional until you upload conversation audio)

The first Whisper run downloads the model named in `WHISPER_MODEL`. The default `large-v3` is large and slow on first use.

## Clone and environment

From the repository root:

```bash
cp .env.example .env
```

Edit `.env`. At minimum, change `JWT_SECRET` for anything beyond a throwaway local box. Set `OPENAI_API_KEY` if you will process conversation audio past transcription.

| Variable | Default | Purpose |
| --- | --- | --- |
| `MONGODB_URI` | `mongodb://127.0.0.1:27017` | Mongo connection string |
| `MONGODB_DB` | `case2case` | Database name |
| `JWT_SECRET` | `change-me-in-production` | Signs session JWTs |
| `OPENAI_API_KEY` | empty | Required for translation, summary, and suggested category |
| `OPENAI_MODEL` | `gpt-4o-mini` | Chat model for the AI step |
| `WHISPER_MODEL` | `large-v3` | Local faster-whisper model. Use `small` for a lighter test |
| `DATA_DIR` | `./data` | Uploaded audio lives under this path |
| `CORS_ORIGINS` | Flutter web URLs | Extra allowed origins. Localhost any port is also allowed by regex |

The API loads `.env` from the **repository root** (not `backend/`).

## Start MongoDB

```bash
docker compose up -d mongo
```

This publishes MongoDB on `127.0.0.1:27017` and stores data in the `case2case_mongo` Docker volume.

## Start the API

```bash
chmod +x run-api.sh run-ui.sh
./run-api.sh
```

The script creates `backend/.venv` if needed, installs `backend/requirements.txt`, and runs Uvicorn with reload on **http://127.0.0.1:8765**.

Health check: `GET http://127.0.0.1:8765/api/health` should return `{"ok": true}`.

On first start, if no DuperAdmin exists, the API seeds **duperadmin** / **duperadmin** with `mustChangePassword` set. Change that password immediately after login.

## Start the UI

In a second terminal:

```bash
./run-ui.sh
```

This runs `flutter pub get`, then Flutter **web-server** on **http://127.0.0.1:8080**. The app calls the API at `http://127.0.0.1:8765` (override with `--dart-define=API_BASE=...`). If port 8765 is not FastAPI, login will fail.

For Chrome, macOS, or a device instead of `web-server`:

```bash
cd frontend
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8765
flutter run -d macos --dart-define=API_BASE=http://127.0.0.1:8765
```

On the Android emulator the app already defaults to `http://10.0.2.2:8765`.

## First login

1. Open http://127.0.0.1:8080
2. Sign in as `duperadmin` / `duperadmin`
3. Set a new password when prompted
4. Create at least one workspace (type, categories, tags, assigned agents) before anyone can file cases

Customers can also use **Register** on the login page (role is always `customer`).

## Audio processing notes

- Conversation audio can be attached to any case type
- Supported extensions: `.mp3`, `.wav`, `.m4a`, `.mp4`, `.ogg`, `.webm`, `.aac`, `.flac`
- Transcription uses GPU (`cuda` / `float16`) when available, otherwise CPU (`int8`)
- If `OPENAI_API_KEY` is missing, transcription can still run; the later AI steps fail and the case AI status becomes `failed`
- Uploads are stored under `DATA_DIR/uploads/<case-id>/`

## Manual commands (optional)

Equivalent to the helper scripts:

```bash
# API
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export PYTHONPATH=.
uvicorn app.main:app --reload --host 0.0.0.0 --port 8765

# UI
cd frontend
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  --dart-define=API_BASE=http://127.0.0.1:8765
```

## Stop

- Stop the two shell processes (Ctrl+C)
- Mongo: `docker compose stop mongo` (data remains in the volume)
