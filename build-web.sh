#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-godot}"
EXPORT_DIR="export/web"
EXPORT_PRESET="${EXPORT_PRESET:-Web}"
BUILD_MODE="${BUILD_MODE:-release}"  # release or debug

# ── Prerequisite checks ───────────────────────────────────────────────────
if ! command -v "$GODOT" &>/dev/null; then
  echo "Error: Godot executable not found at '$GODOT'."
  echo "Set the GODOT env var or install Godot."
  echo "  export GODOT=/path/to/godot"
  exit 1
fi

# ── Build ─────────────────────────────────────────────────────────────────
mkdir -p "$EXPORT_DIR"

if [ "$BUILD_MODE" = "release" ]; then
  echo "Exporting $EXPORT_PRESET (release) ..."
  "$GODOT" --headless --export-release "$EXPORT_PRESET"
else
  echo "Exporting $EXPORT_PRESET (debug) ..."
  "$GODOT" --headless --export-debug "$EXPORT_PRESET"
fi

echo "Web build finished. Artifacts in $EXPORT_DIR/"
ls -lh "$EXPORT_DIR/"
