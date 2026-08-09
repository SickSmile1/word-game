#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-godot}"
EXPORT_DIR="export"
EXPORT_PRESET="${EXPORT_PRESET:-Android}"
BUILD_MODE="${BUILD_MODE:-release}"  # release or debug

# ── Prerequisite checks ───────────────────────────────────────────────────
if ! command -v "$GODOT" &>/dev/null; then
  echo "Error: Godot executable not found at '$GODOT'."
  echo "Set the GODOT env var or install Godot."
  echo "  export GODOT=/path/to/godot"
  exit 1
fi

if [ -z "${JAVA_HOME:-}" ]; then
  echo "Warning: JAVA_HOME is not set. Gradle may fail."
  echo "  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
fi

if [ -z "${ANDROID_HOME:-}" ]; then
  echo "Warning: ANDROID_HOME is not set. Gradle may fail."
  echo "  export ANDROID_HOME=\$HOME/Android/Sdk"
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

echo "Android build finished. Artifacts in $EXPORT_DIR/"
ls -lh "$EXPORT_DIR/"
