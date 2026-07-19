#!/usr/bin/env bash
# Append Web Push handlers to Flutter's generated service worker.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SW="$ROOT/build/web/flutter_service_worker.js"
HANDLERS="$ROOT/web/push_handlers.js"

if [[ ! -f "$SW" ]]; then
  echo "Missing $SW — run flutter build web first." >&2
  exit 1
fi

if grep -q "bitachon-reminder" "$SW" 2>/dev/null; then
  echo "Push handlers already present in service worker."
  exit 0
fi

{
  echo ""
  echo "/* === Sagesse Bitachon Web Push handlers === */"
  cat "$HANDLERS"
} >> "$SW"

echo "Injected push handlers into flutter_service_worker.js"
