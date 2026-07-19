#!/usr/bin/env bash
# Build Flutter Web for Vercel (or local CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter-sdk}"
  if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
    echo "Installing Flutter SDK into $FLUTTER_DIR ..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

flutter --version
flutter config --no-analytics --enable-web
flutter pub get
BASE_HREF="${BASE_HREF:-/}"
flutter build web --release --no-wasm-dry-run --base-href "$BASE_HREF"
bash "$ROOT/tool/inject_push_handlers.sh"

echo "Web build ready in build/web (base-href=$BASE_HREF)"
