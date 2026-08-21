#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/frontend"
flutter pub get
exec flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  --dart-define=API_BASE=http://127.0.0.1:8765
