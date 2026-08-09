#!/usr/bin/env bash
# Automated two-process loopback test through the real signaling server.
# Spawns a headless host and guest that connect via WebRTC, exchange a
# GameSession snapshot, and relay a guest action back to the host.
set -uo pipefail

DENO="${DENO:-$HOME/.deno/bin/deno}"
GODOT="${GODOT:-/var/lib/flatpak/exports/bin/org.godotengine.Godot}"
SIGNAL_DIR="$(cd "$(dirname "$0")/../../tools/webrtc_signaling" && pwd)"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROOM=$((100000 + RANDOM % 900000))

"$DENO" run --allow-net --unstable-kv "$SIGNAL_DIR/server.ts" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 2

if ! curl -s http://127.0.0.1:9080/ | grep -q "scrabble signaling"; then
	echo "FAIL: signaling server did not start"
	exit 1
fi

HOST_LOG=$(mktemp)
GUEST_LOG=$(mktemp)

SCRABBLE_SIGNALING_URL=ws://127.0.0.1:9080/ "$GODOT" --headless --path "$ROOT" \
	res://tests/e2e/loopback_driver.tscn -- host "$ROOM" >"$HOST_LOG" 2>&1 &
HOST=$!
sleep 2

SCRABBLE_SIGNALING_URL=ws://127.0.0.1:9080/ "$GODOT" --headless --path "$ROOT" \
	res://tests/e2e/loopback_driver.tscn -- guest "$ROOM" >"$GUEST_LOG" 2>&1 &
GUEST=$!

wait "$GUEST"
GUEST_RC=$?
wait "$HOST"
HOST_RC=$?

echo "--- HOST ---"
cat "$HOST_LOG"
echo "--- GUEST ---"
cat "$GUEST_LOG"
echo "HOST_RC=$HOST_RC GUEST_RC=$GUEST_RC"

if [ "$HOST_RC" -eq 0 ] && [ "$GUEST_RC" -eq 0 ]; then
	echo "LOOPBACK PASS"
	exit 0
fi
echo "LOOPBACK FAIL"
exit 1
