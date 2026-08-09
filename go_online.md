# Two-Player WebRTC Multiplayer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two-player Scrabble over the network (web, Android, desktop), host-authoritative with redacted full-state sync, LAN-first but internet-capable via a free Deno Deploy signaling server.

**Architecture:** WebRTC P2P using Godot's built-in `WebRTCMultiplayerPeer` + `MultiplayerAPI`. Host is authoritative; all actions flow to the host, which validates, applies, and broadcasts a **redacted** full-state snapshot (opponent rack and tile-bag contents are never sent). A tiny Deno Deploy server brokers only the initial SDP/ICE handshake; game data is P2P afterward.

**Tech Stack:** Godot 4.7 (GDScript), Godot WebRTC classes, GUT test framework (`make test`), Deno + Deno KV + BroadcastChannel (signaling server), `gdlint`/`gdformat` (`make lint`/`make lint-fix`).

## Global Constraints

- Godot 4.7 (`project.godot` features say 4.6; installed binary is 4.7 — export templates already installed).
- Tests use GUT, auto-discovered from `tests/` (prefix `test_`, suffix `.gd`). Run: `make test`.
- Lint with `make lint` (gdlint), format with `make lint-fix` (gdformat) on `scripts/ tests/`.
- **No account system**; short numeric room codes only.
- **Online games never touch SaveManager**: no slot assignment, no autosave, no `delete_save`.
- **Hidden info rules:** the guest client must never hold the tile-bag pool or the host's rack letters in memory.
- **STUN-only by default** (`stun:stun.l.google.com:19302`, `stun:stun1.l.google.com:19302`). TURN stays an optional, commented-out config.
- **No IP logging/storage** on the signaling server; Deno KV room records get a TTL and are deleted on disconnect.
- `protocol_version = 1` in every session payload; mismatch → reject connection.
- Existing VS-AI behavior and all existing tests must stay green.
- `SIGNALING_URL` is resolved at runtime: env var `SCRABBLE_SIGNALING_URL` overrides the constant in `scripts/net/SignalingConfig.gd`.

---

## Design Summary (from brainstorming)

- **Sync model:** Authoritative host + full-state snapshots. No deterministic RNG requirement (bag is drawn only on the host).
- **Rematch:** guest requests at game-over; host restarts with a fresh session and broadcasts it.
- **Turn ownership:** a new `WAITING` state + `_my_turn` flag; input enabled only when `HUMAN_TURN && _my_turn`.
- **Redaction:** host serializes for the guest with the host's rack masked (`"*".repeat(len)`) and bag contents replaced by a count. Guest's own rack is sent in full.
- **Signaling:** Deno Deploy `wss://` endpoint; each socket holds a per-room `BroadcastChannel` (relays messages across edge isolates); Deno KV (with TTL) is only a room registry for the join handshake.

## File Structure

**New files**
- `scripts/game/GameSession.gd` — pure state container + dual (full/redacted) serializer.
- `scripts/net/SignalingConfig.gd` — `signaling_url` (const + env override).
- `scripts/net/SignalingClient.gd` — `WebSocketPeer` to signaling URL; drives a `WebRTCPeerConnection`; ICE candidate queue.
- `scripts/net/NetworkManager.gd` — autoload `Net`; owns `WebRTCMultiplayerPeer`, RPCs, teardown.
- `scenes/lobby/Lobby.tscn` + `scripts/ui/Lobby.gd` — create/join room UI (fixes the dead "Online" link in MainMenu).
- `tools/webrtc_signaling/server.ts` + `server_test.ts` + `README.md` — Deno signaling server + tests + deploy guide.
- `tests/unit/test_game_session.gd`, `tests/unit/test_network_manager.gd`, `tests/unit/test_lobby.gd`.

**Modified files**
- `project.godot` — add autoload `Net="*res://scripts/net/NetworkManager.gd"`.
- `scripts/ui/Game.gd` — additive online branch.
- `Makefile` — `make signal-dev` target.
- `Specifications.md` — document the network architecture.

---

## Milestone 0 — `GameSession`: redacted state serialization (pure logic, TDD)

**Files:**
- Create: `scripts/game/GameSession.gd`
- Create: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces:
  - `class_name GameSession extends RefCounted`
  - `const PROTOCOL_VERSION := 1`
  - `enum Player { P0 = 0, P1 = 1 }`
  - `var board` (a `Board`), `var bag_pool: Array[String]`, `var bag_count: int`
  - `var racks: Array[String]` (`racks[P0]`, `racks[P1]`), `var scores: Array[int]`, `var consecutive_passes: int`, `var turn: int`, `var game_over: bool`
  - `func new_game() -> void` — builds a fresh authoritative state (host side): new `Board`, new `TileBag`, both racks drawn 7, `turn = 0`.
  - `func to_dict_for_player(me: int) -> Dictionary`
  - `static func from_dict_for_player(data: Dictionary, me: int) -> GameSession`

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_game_session.gd`:

```gdscript
extends GutTest

const GameSession = preload("res://scripts/game/GameSession.gd")

func _session() -> GameSession:
	var s := GameSession.new()
	s.new_game()
	return s

func test_new_game_draws_racks_and_host_starts():
	var s := _session()
	assert_eq(s.racks[0].length(), 7)
	assert_eq(s.racks[1].length(), 7)
	assert_eq(s.turn, GameSession.Player.P0)
	assert_eq(s.scores, [0, 0])
	assert_false(s.game_over)

func test_self_snapshot_is_full_fidelity():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P0)
	assert_true(data.has("bag"), "host snapshot must include bag")
	assert_eq(data.bag.size(), s.bag_pool.size())
	assert_eq(data.racks[0], s.racks[0])
	assert_eq(data.racks[1], s.racks[1])
	var restored := GameSession.from_dict_for_player(data, GameSession.Player.P0)
	assert_eq(restored.racks[0], s.racks[0])
	assert_eq(restored.racks[1], s.racks[1])
	assert_eq(restored.bag_pool, s.bag_pool)
	assert_eq(restored.turn, s.turn)
	assert_eq(restored.scores, s.scores)

func test_guest_snapshot_redacts_host_rack_and_bag():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P1)
	assert_false(data.has("bag"), "guest snapshot must NOT include bag contents")
	assert_eq(data.bag_count, s.bag_pool.size(), "guest sees only bag count")
	assert_eq(data.racks[0], "*".repeat(s.racks[0].length()), "host rack masked")
	assert_eq(data.racks[1], s.racks[1], "guest sees own rack in full")
	assert_eq(data.board.size(), 15)
	assert_eq(data.version, GameSession.PROTOCOL_VERSION)

func test_guest_restore_never_materializes_bag():
	var s := _session()
	var data := s.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(data, GameSession.Player.P1)
	assert_eq(guest.bag_pool, [], "guest must not hold bag tiles")
	assert_eq(guest.bag_count, data.bag_count)

func test_round_trip_keeps_scores_passes_and_game_over():
	var s := _session()
	s.scores = [42, 7]
	s.consecutive_passes = 2
	s.turn = GameSession.Player.P1
	s.game_over = true
	var data := s.to_dict_for_player(GameSession.Player.P1)
	var restored := GameSession.from_dict_for_player(data, GameSession.Player.P1)
	assert_eq(restored.scores, [42, 7])
	assert_eq(restored.consecutive_passes, 2)
	assert_eq(restored.turn, GameSession.Player.P1)
	assert_true(restored.game_over)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: errors — `GameSession` script/resource not found.

- [ ] **Step 3: Write the minimal implementation**

`scripts/game/GameSession.gd`:

```gdscript
class_name GameSession
extends RefCounted

const Board = preload("res://scripts/game/Board.gd")
const TileBag = preload("res://scripts/game/TileBag.gd")

const PROTOCOL_VERSION := 1

enum Player { P0 = 0, P1 = 1 }

var board: Board
var bag_pool: Array[String] = []
var bag_count: int = 0
var racks: Array[String] = ["", ""]
var scores: Array[int] = [0, 0]
var consecutive_passes: int = 0
var turn: int = Player.P0
var game_over: bool = false


func new_game() -> void:
	board = Board.new()
	var bag := TileBag.new()
	bag_pool = bag._pool.duplicate()
	racks[Player.P0] = bag.draw_balanced_tiles(7)
	racks[Player.P1] = bag.draw_balanced_tiles(7)
	scores = [0, 0]
	consecutive_passes = 0
	turn = Player.P0
	game_over = false


func to_dict_for_player(me: int) -> Dictionary:
	var cells := []
	for r in range(15):
		var row := []
		for c in range(15):
			row.append(board.get_tile(r, c) if board.is_occupied(r, c) else null)
		cells.append(row)

	var data := {
		"version": PROTOCOL_VERSION,
		"board": cells,
		"scores": scores.duplicate(),
		"passes": consecutive_passes,
		"turn": turn,
		"game_over": game_over,
		"bag_count": bag_pool.size(),
	}

	if me == Player.P0:
		data["racks"] = racks.duplicate()
		data["bag"] = bag_pool.duplicate()
	else:
		# Redact the host's rack (P0) and never expose the bag contents.
		data["racks"] = ["*".repeat(racks[Player.P0].length()), racks[Player.P1]]
	return data


static func from_dict_for_player(data: Dictionary, me: int) -> GameSession:
	var s := GameSession.new()
	s.board = Board.new()
	var board_data: Array = data.get("board", [])
	for r in range(board_data.size()):
		var row: Array = board_data[r]
		for c in range(row.size()):
			if row[c] != null:
				s.board.place_tile(r, c, row[c])
	s.scores = (data.get("scores", [0, 0]) as Array).duplicate()
	s.consecutive_passes = int(data.get("passes", 0))
	s.turn = int(data.get("turn", 0))
	s.game_over = bool(data.get("game_over", false))
	s.bag_count = int(data.get("bag_count", 0))
	var racks_data: Array = data.get("racks", ["", ""])
	s.racks[Player.P0] = racks_data[Player.P0]
	s.racks[Player.P1] = racks_data[Player.P1]
	# The authoritative host holds the bag; everyone else gets a shadow (count only).
	if data.has("bag"):
		s.bag_pool = (data.get("bag", []) as Array).duplicate()
	return s
```

> Note: `from_dict_for_player` stores the masked `"***"` rack for the host's rack on the guest side too (it is never rendered), so `racks` has a consistent shape on both sides.

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: all `test_game_session_*` pass; existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/game/GameSession.gd tests/unit/test_game_session.gd
git commit -m "feat: add GameSession with redacted state serialization"
```

---

## Milestone 1 — Signaling server (Deno) + manual free deployment

### Task 1A: Signaling server code (TDD with `deno test`)

**Files:**
- Create: `tools/webrtc_signaling/server.ts`
- Create: `tools/webrtc_signaling/server_test.ts`

**Interfaces:**
- Produces (pure, testable exports from `server.ts`):
  - `export const MAX_PLAYERS = 2`
  - `export const ROOM_TTL_MS = 15 * 60 * 1000`
  - `export function generate_room_code(): string` — 6-digit numeric code, collision-checked server-side.
  - `export function parse_message(text: string): Record<string, unknown> | null`
  - Message types in: `create {room?}`, `join {room}`, `session {subtype: "offer"|"answer", sdp}`, `candidate {mid, index, sdp}`.
  - Message types out (to the peer): `created {room, slot}`, `joined {room, slot}`, `session {subtype, sdp}`, `candidate {mid, index, sdp}`, `error {reason}`.
- Produces (server behavior, manually verified):
  - `create`: allocates a code, registers room in Deno KV with `expireIn: ROOM_TTL_MS`, opens a per-room `BroadcastChannel`, replies `{type:"created", room, slot:0}`.
  - `join`: looks up room in KV; if full → `{type:"error", reason:"room_full"}`; if missing → `{type:"error", reason:"not_found"}`.
  - **Relay:** each socket keeps its `BroadcastChannel` open; incoming `session`/`candidate` are posted to the channel, and `channel.onmessage` forwards to the socket (tagged with a random `peer` id to ignore the sender's own echo). Works across edge isolates; KV is registry-only.
  - `close` / socket disconnect: close the channel; delete the KV room record.
  - No IP logging: log room codes and message types only.

- [ ] **Step 1: Write the failing tests**

`tools/webrtc_signaling/server_test.ts`:

```ts
import { assertEquals, assertMatch, assert } from "jsr:@std/assert";
import {
  generate_room_code,
  parse_message,
  MAX_PLAYERS,
  ROOM_TTL_MS,
} from "./server.ts";

Deno.test("room code is 6 digits", () => {
  assertMatch(generate_room_code(), /^\d{6}$/);
});

Deno.test("parse_message accepts join with room", () => {
  const m = parse_message(`{"type":"join","room":"123456"}`);
  assertEquals(m?.type, "join");
  assertEquals(m?.room, "123456");
});

Deno.test("parse_message rejects join without room", () => {
  assertEquals(parse_message(`{"type":"join"}`), null);
});

Deno.test("parse_message allows create without room", () => {
  const m = parse_message(`{"type":"create"}`);
  assertEquals(m?.type, "create");
});

Deno.test("parse_message rejects garbage", () => {
  assertEquals(parse_message("not json"), null);
});

Deno.test("parse_message accepts session/candidate relays", () => {
  assert(parse_message(`{"type":"session","subtype":"offer","sdp":"x"}`) !== null);
  assert(parse_message(`{"type":"candidate","mid":"0","index":0,"sdp":"x"}`) !== null);
});

Deno.test("constants sane", () => {
  assertEquals(MAX_PLAYERS, 2);
  assert(ROOM_TTL_MS <= 20 * 60 * 1000);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd tools/webrtc_signaling && deno test`
Expected: FAIL — `server.ts` does not exist.

> Requires `deno` installed locally: `curl -fsSL https://deno.land/install.sh | sh` (user-performed, one-time).

- [ ] **Step 3: Write the minimal implementation**

`tools/webrtc_signaling/server.ts`:

```ts
export const MAX_PLAYERS = 2;
export const ROOM_TTL_MS = 15 * 60 * 1000;

const kv = await Deno.openKv();

export function generate_room_code(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function parse_message(text: string): Record<string, unknown> | null {
  try {
    const obj = JSON.parse(text);
    if (typeof obj?.type !== "string") return null;
    if (obj.type === "join" && obj.room === undefined) return null;
    return obj;
  } catch {
    return null;
  }
}

async function resolve_room(requested: string): Promise<string> {
  if (requested) return requested;
  for (let i = 0; i < 10; i++) {
    const candidate = generate_room_code();
    const existing = await kv.get(["room", candidate]);
    if (!existing.value) return candidate;
  }
  throw new Error("could not allocate room");
}

Deno.serve({ port: 9080 }, async (req) => {
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("scrabble signaling", { status: 200 });
  }
  const { socket, response } = Deno.upgradeWebSocket(req);

  let room = "";
  let channel: BroadcastChannel | null = null;
  const peer_id = crypto.randomUUID();

  const open_channel = (code: string) => {
    channel = new BroadcastChannel(`room:${code}`);
    channel.onmessage = (ev) => {
      const msg = JSON.parse(String(ev.data));
      if (msg.peer === peer_id) return; // ignore our own echo
      socket.send(JSON.stringify(msg));
    };
  };

  socket.onmessage = async (ev) => {
    const msg = parse_message(String(ev.data));
    if (!msg) return;

    switch (msg.type) {
      case "create": {
        room = await resolve_room(String(msg.room ?? ""));
        await kv.set(["room", room], { players: 1 }, { expireIn: ROOM_TTL_MS });
        open_channel(room);
        socket.send(JSON.stringify({ type: "created", room, slot: 0 }));
        break;
      }
      case "join": {
        room = String(msg.room);
        const entry = await kv.get(["room", room]);
        if (!entry.value) {
          socket.send(JSON.stringify({ type: "error", reason: "not_found" }));
          break;
        }
        const players = (entry.value as { players: number }).players;
        if (players >= MAX_PLAYERS) {
          socket.send(JSON.stringify({ type: "error", reason: "room_full" }));
          break;
        }
        await kv.set(["room", room], { players: players + 1 }, { expireIn: ROOM_TTL_MS });
        open_channel(room);
        socket.send(JSON.stringify({ type: "joined", room, slot: players }));
        break;
      }
      case "session":
      case "candidate":
        if (channel) {
          channel.postMessage(JSON.stringify({ peer: peer_id, type: msg.type, ...msg }));
        }
        break;
    }
  };

  socket.onclose = () => {
    channel?.close();
    if (room) kv.delete(["room", room]);
  };

  return response;
});
```

> **Note:** the two room sockets relay through the same `room:<code>` BroadcastChannel, so messages written by either isolate are delivered to the other. KV only registers the room for the join handshake and is deleted on disconnect. If a free-tier limitation ever breaks cross-isolate delivery, the mailbox fallback (host offer → KV → guest answer → `kv.watch`) is documented in `README.md`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tools/webrtc_signaling && deno test`
Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/webrtc_signaling/
git commit -m "feat: add Deno signaling server with room relay"
```

### Task 1B: Manual deployment to Deno Deploy (USER-PERFORMED — needs your account)

> This task requires **you** to register and run cloud steps. The app code is unaffected if you skip it for now — local dev falls back to a locally-run server via `make signal-dev`.

**Files:**
- Create: `tools/webrtc_signaling/README.md` (deploy + local-run instructions; write it so the commands below are available).

- [ ] **Step 1 (you):** Install the Deno CLI if not present:
```bash
curl -fsSL https://deno.land/install.sh | sh
```

- [ ] **Step 2 (you):** Create a free Deno Deploy account at https://dash.deno.com (no credit card). Note your project name (e.g. `scrabble-signal`).

- [ ] **Step 3 (you):** Smoke-test locally:
```bash
cd tools/webrtc_signaling
deno run --allow-net --unstable-kv server.ts
```

- [ ] **Step 4 (you):** Deploy:
```bash
cd tools/webrtc_signaling
deno login
deno deploy --project scrabble-signal --allow-net --unstable-kv server.ts
```

- [ ] **Step 5 (you):** Confirm the endpoint responds (non-WebSocket request returns "scrabble signaling"):
```bash
curl https://scrabble-signal.deno.dev/
```

- [ ] **Step 6 (you):** Tell me the URL. The signaling WebSocket endpoint becomes `wss://scrabble-signal.deno.dev/`. I will set `SIGNALING_URL` in `scripts/net/SignalingConfig.gd` to it (or you set the env var `SCRABBLE_SIGNALING_URL` yourself).

- [ ] **Step 7:** Commit the README (code side, after writing it):
```bash
git add tools/webrtc_signaling/README.md
git commit -m "docs: add signaling server deploy and local-run guide"
```

---

## Milestone 2 — Godot networking: `SignalingConfig`, `SignalingClient`, `NetworkManager`

**Files:**
- Create: `scripts/net/SignalingConfig.gd`
- Create: `scripts/net/SignalingClient.gd`
- Create: `scripts/net/NetworkManager.gd`
- Create: `tests/unit/test_network_manager.gd`
- Modify: `project.godot` (add `Net` autoload)

**Interfaces:**
- Produces:
  - `SignalingConfig` (RefCounted, static): `const DEFAULT_URL := "wss://scrabble-signal.deno.dev/"`, `static func get_url() -> String` (env `SCRABBLE_SIGNALING_URL` override).
  - `SignalingClient` (Node):
    - `signal host_connected(room_code: String, slot: int)`
    - `signal host_error(reason: String)`
    - `signal connection_open(pc: WebRTCPeerConnection)` — emitted when the peer connection reaches `STATE_CONNECTED` (P2P up). `WebRTCMultiplayerPeer.add_peer()` creates the data channels itself, so no manual channel creation.
    - `func start_host(room: String = "") -> void`
    - `func start_guest(room: String) -> void`
    - `func close() -> void`
  - `NetworkManager` (autoload `Net`):
    - `var active := false`, `var is_host := false`, `var remote_peer_id := 1`
    - `signal session_started(host: bool)`, `signal peer_connected`, `signal peer_disconnected`, `signal net_error(reason: String)`
    - `signal submit_action_received(sender_id: int, action: Dictionary)`, `signal state_received(state: Dictionary)`
    - `func start_host(room_code: String) -> bool`, `func start_guest(room_code: String) -> bool`
    - `func send_action(action: Dictionary) -> void` — host runs the handler locally (sender 1); guest `rpc()`s to the server.
    - `@rpc("any_peer", "reliable") func submit_action(action: Dictionary)`
    - `func send_state(state: Dictionary) -> void` → `rpc_id(remote_peer_id, "receive_state", state)`
    - `@rpc("authority", "call_remote", "reliable") func receive_state(state: Dictionary)`
    - `func teardown() -> void`

**Signaling protocol (client ↔ server):**
- Out: `create {room?}`, `join {room}`, `session {subtype:"offer"|"answer", sdp}`, `candidate {mid, index, sdp}`, `close`.
- In: `created {room, slot}`, `joined {room, slot}`, `session {subtype, sdp}`, `candidate {mid, index, sdp}`, `error {reason}`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_network_manager.gd` (pure — no live network; tests URL resolution and message building):

```gdscript
extends GutTest

const SignalingConfig = preload("res://scripts/net/SignalingConfig.gd")
const SignalingClient = preload("res://scripts/net/SignalingClient.gd")

func test_env_url_override():
	OS.set_environment("SCRABBLE_SIGNALING_URL", "wss://example.test/")
	assert_eq(SignalingConfig.get_url(), "wss://example.test/")
	OS.set_environment("SCRABBLE_SIGNALING_URL", "")

func test_default_url_is_wss():
	OS.set_environment("SCRABBLE_SIGNALING_URL", "")
	assert_true(SignalingConfig.get_url().begins_with("wss://"), "signaling url must be wss")

func test_intent_message_builders():
	var client := SignalingClient.new()
	client._is_host = true
	assert_eq(JSON.stringify(client._build_intent()), '{"type":"create","room":""}')
	client._is_host = false
	client._room = "123456"
	assert_eq(JSON.stringify(client._build_intent()), '{"type":"join","room":"123456"}')
	client.free()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `SignalingConfig`/`SignalingClient` not found.

- [ ] **Step 3: Write the minimal implementation**

`scripts/net/SignalingConfig.gd`:

```gdscript
class_name SignalingConfig
extends RefCounted

const DEFAULT_URL := "wss://scrabble-signal.deno.dev/"


static func get_url() -> String:
	var env := OS.get_environment("SCRABBLE_SIGNALING_URL")
	return env if not env.is_empty() else DEFAULT_URL
```

`scripts/net/SignalingClient.gd`:

```gdscript
extends Node

const Config = preload("res://scripts/net/SignalingConfig.gd")

signal host_connected(room_code: String, slot: int)
signal host_error(reason: String)
signal connection_open(pc: WebRTCPeerConnection)

const ICE_SERVERS := {
	"iceServers": [
		{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	],
}

var _ws: WebSocketPeer
var _pc: WebRTCPeerConnection
var _is_host := false
var _room := ""
var _sent_intent := false
var _remote_description_set := false
var _handshake_done := false
var _pending_candidates: Array[Dictionary] = []


func start_host(room: String = "") -> void:
	_is_host = true
	_room = room
	_connect()


func start_guest(room: String) -> void:
	_is_host = false
	_room = room
	_connect()


func _connect() -> void:
	_pc = WebRTCPeerConnection.new()
	_pc.initialize(ICE_SERVERS)
	_pc.session_description_created.connect(_on_session_created)
	_pc.ice_candidate_created.connect(_on_ice_candidate)
	_pc.connection_state_changed.connect(_on_connection_state)

	_ws = WebSocketPeer.new()
	_ws.connect_to_url(Config.get_url())


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _sent_intent:
			_sent_intent = true
			_send(_build_intent())
		while _ws.get_available_packet_count() > 0:
			_handle_message(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and not _handshake_done:
		host_error.emit("Signaling connection lost")


func _build_intent() -> Dictionary:
	return {"type": "create", "room": _room} if _is_host else {"type": "join", "room": _room}


func _handle_message(text: String) -> void:
	var data = JSON.parse_string(text)
	if data == null:
		return
	match data.type:
		"created", "joined":
			_room = data.room if data.has("room") else _room
			host_connected.emit(_room, data.slot)
			if _is_host:
				_pc.create_offer()
		"session":
			_pc.set_remote_description(data.subtype, data.sdp)
			_remote_description_set = true
			_flush_candidates()
			if data.subtype == "offer":
				_pc.create_answer()
		"candidate":
			if _remote_description_set:
				_pc.add_ice_candidate(data.mid, data.index, data.sdp)
			else:
				_pending_candidates.append(data)  # queue until remote description is set
		"error":
			host_error.emit(data.reason)


func _on_session_created(subtype: String, sdp: String) -> void:
	_pc.set_local_description(subtype, sdp)
	_send({"type": "session", "subtype": subtype, "sdp": sdp})


func _on_ice_candidate(mid: String, index: int, sdp: String) -> void:
	_send({"type": "candidate", "mid": mid, "index": index, "sdp": sdp})


func _on_connection_state(state: int) -> void:
	if state == WebRTCPeerConnection.STATE_CONNECTED:
		_handshake_done = true
		connection_open.emit(_pc)
	elif state == WebRTCPeerConnection.STATE_FAILED and not _handshake_done:
		host_error.emit("Peer connection failed — try again or check your network")


func _flush_candidates() -> void:
	for c in _pending_candidates:
		_pc.add_ice_candidate(c.mid, c.index, c.sdp)
	_pending_candidates.clear()


func _send(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.put_packet(JSON.stringify(msg).to_utf8_buffer())


func close() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	if _pc != null:
		_pc.close()
		_pc = null
	_pending_candidates.clear()
```

`scripts/net/NetworkManager.gd` (autoload `Net`):

```gdscript
extends Node

const SignalingClient = preload("res://scripts/net/SignalingClient.gd")

signal session_started(host: bool)
signal peer_connected
signal peer_disconnected
signal net_error(reason: String)
signal submit_action_received(sender_id: int, action: Dictionary)
signal state_received(state: Dictionary)

var active := false
var is_host := false
var remote_peer_id := 1
var _client: SignalingClient
var _mp: WebRTCMultiplayerPeer


func start_host(room_code: String) -> bool:
	_init_client(room_code, true)
	return true


func start_guest(room_code: String) -> bool:
	_init_client(room_code, false)
	return true


func _init_client(room_code: String, host: bool) -> void:
	is_host = host
	remote_peer_id = 2 if host else 1
	_client = SignalingClient.new()
	add_child(_client)
	_client.host_connected.connect(_on_host_connected)
	_client.host_error.connect(_on_net_error)
	_client.connection_open.connect(_on_connection_open)
	if host:
		_client.start_host(room_code)
	else:
		_client.start_guest(room_code)


func _on_host_connected(_room: String, _slot: int) -> void:
	pass  # room/slot informational; used by Lobby


func _on_connection_open(pc: WebRTCPeerConnection) -> void:
	_mp = WebRTCMultiplayerPeer.new()
	if is_host:
		_mp.create_server()
		_mp.add_peer(pc, remote_peer_id)  # guest id is always 2
	else:
		_mp.create_client(2)
		_mp.add_peer(pc, 1)              # server is always peer 1
	multiplayer.multiplayer_peer = _mp
	active = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit(is_host)


func _on_peer_connected(_id: int) -> void:
	peer_connected.emit()


func _on_peer_disconnected(_id: int) -> void:
	peer_disconnected.emit()


func _on_net_error(reason: String) -> void:
	net_error.emit(reason)


func send_action(action: Dictionary) -> void:
	if is_host:
		submit_action_received.emit(1, action)
	else:
		submit_action.rpc(action)


@rpc("any_peer", "reliable")
func submit_action(action: Dictionary) -> void:
	submit_action_received.emit(multiplayer.get_remote_sender_id(), action)


func send_state(state: Dictionary) -> void:
	rpc_id(remote_peer_id, "receive_state", state)


@rpc("authority", "call_remote", "reliable")
func receive_state(state: Dictionary) -> void:
	state_received.emit(state)


func teardown() -> void:
	active = false
	if _mp != null:
		multiplayer.multiplayer_peer = null
		_mp = null
	if _client != null:
		_client.close()
		_client.queue_free()
		_client = null
```

`project.godot` autoload addition:

```
Net="*res://scripts/net/NetworkManager.gd"
```

> Godot 4.7 API notes (verified): `WebRTCPeerConnection.initialize({"iceServers": [{"urls": [...]}]})` uses the camelCase `iceServers` key; `WebRTCMultiplayerPeer.create_client(peer_id)` and `add_peer(pc, peer_id)` create the reliable/unreliable/ordered data channels themselves (the pc must be in `STATE_NEW`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: `test_network_manager` passes; existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/net/ project.godot tests/unit/test_network_manager.gd
git commit -m "feat: add signaling client and NetworkManager autoload"
```

---

## Milestone 3 — Lobby scene (create / join room UI)

**Files:**
- Create: `scenes/lobby/Lobby.tscn`
- Create: `scripts/ui/Lobby.gd`
- Create: `tests/unit/test_lobby.gd`

**Interfaces:**
- Consumes: `Net` autoload (`start_host`, `start_guest`, signals `host_connected`, `session_started`, `peer_connected`, `net_error`).
- Produces: on `peer_connected` → `get_tree().change_scene_to_file("res://scenes/game/Game.tscn")`. On `net_error` → show reason.

**Scene node tree** (mirror MainMenu theming pattern, programmatic `StyleBoxFlat`):
- `Lobby (Control, full rect)` → `Background (ColorRect)`, `Panel (Panel)` centered → `VBoxContainer`:
  - `Title (Label)` "ONLINE"
  - `ModeButtons (HBox)` → `CreateButton`, `JoinButton`
  - `RoomPanel (VBox)` hidden until a mode is chosen:
    - `RoomLabel (Label)` — room code or "Waiting for opponent…"
    - `CodeInput (LineEdit)` — shown in join mode, `max_length=6`
    - `StatusLabel (Label)`
    - `BackButton (Button)`
  - `PrivacyNote (Label)` — small muted text: "Online play connects you directly to your opponent (WebRTC). IP addresses are exchanged between participants only."
- Connections: Create → `Net.start_host("")`; Join → `Net.start_guest(CodeInput.text)`.

**Script** `scripts/ui/Lobby.gd`:
- `_ready()` → theme (reuse `MainMenu._make_menu_style` pattern), connect buttons, connect `Net.session_started`, `Net.peer_connected`, `Net.net_error`, `Net.host_connected`.
- Create pressed → `Net.start_host("")`; Join pressed → `Net.start_guest(CodeInput.text)`.
- On `host_connected(code, _slot)`: show code in `RoomLabel`; status "Waiting for opponent…".
- On `peer_connected`: change scene to `Game.tscn`.
- On `net_error(reason)`: show reason in `StatusLabel`.
- `BackButton` → `Net.teardown()` + change scene to `MainMenu.tscn`.
- `_exit_tree()` → `Net.teardown()` (safety).

- [ ] **Step 1: Write the failing test**

`tests/unit/test_lobby.gd`:

```gdscript
extends GutTest

func test_lobby_scene_loads():
	var scene := load("res://scenes/lobby/Lobby.tscn")
	assert_not_null(scene, "Lobby.tscn must exist (fixes the dead Online button link)")

func test_lobby_script_methods():
	var script := load("res://scripts/ui/Lobby.gd")
	assert_not_null(script, "Lobby.gd must exist")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL — `Lobby.tscn` not found.

- [ ] **Step 3: Implement** — create the scene and script as described. MainMenu's existing `_on_online_pressed()` (scripts/ui/MainMenu.gd:193) already points at `res://scenes/lobby/Lobby.tscn`, so it now works unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scenes/lobby/ scripts/ui/Lobby.gd tests/unit/test_lobby.gd
git commit -m "feat: add lobby scene for create/join online games"
```

---

## Milestone 4 — `Game.gd` online branch

**Files:**
- Modify: `scripts/ui/Game.gd`
- Create: `tests/unit/test_game_online.gd`

**Interfaces:**
- Consumes: `Net.active`, `Net.is_host`, `Net.submit_action_received`, `Net.state_received`, `Net.peer_disconnected`, `Net.send_action(action)`, `Net.send_state(state)`, `Net.teardown()`, `GameSession`.
- Produces: host apply/broadcast and guest restore logic, online-mode UI gating.

**Local role mapping:** `me = GameSession.Player.P0` if `Net.is_host` else `GameSession.Player.P1`. Opponent is the other player.

**Behavior (additive — VS-AI path untouched):**
1. In `_ready()`: if `Net.active` → skip difficulty panel and save-load path; `_online_mode = true`; connect `Net.submit_action_received` (host only) and `Net.state_received` + `Net.peer_disconnected` (both).
2. Add `var _my_turn := false` and enum member `WAITING`. Gate all four input handlers (`_on_board_cell_clicked`, `_on_rack_tile_selected`, `_on_rack_tile_deselected`, `_on_placed_tile_clicked`) on `_state == HUMAN_TURN and _my_turn`; same condition in `_update_display()` button enabling.
3. **Start (host):** after `peer_connected` + dictionary ready: `GameSession.new_game()`, copy fields into `_board`/`_bag`/`_human_rack`/`_ai_rack`/scores (reuse a small `_session_into_fields(s)` helper), `_my_turn = true`, `_state = HUMAN_TURN`, `_update_display()`, then `Net.send_state(_build_guest_state())`.
4. `_build_guest_state()`: `var s := GameSession.new(); _fields_into_session(s); return s.to_dict_for_player(GameSession.Player.P1)`.
5. **Host — action handler:** `_on_net_action(sender_id, action)`: ignore unless `sender_id == Net.remote_peer_id` and it's the sender's turn. Switch on `action.type`:
   - `"play"`: rebuild `_pending_placements` from `action.tiles` (`{pos: Vector2i, letter, rack_index}`), run existing `_validate_move()`; if valid → `_apply_human_move_online()` (same as `_apply_human_move()` but: no `_start_ai_turn`, no autosave, then `_state = WAITING`, `_check_end_game_online()`, `_broadcast()`, `_my_turn = false`); if invalid → send nothing (guest shows the failure via its own local pre-validation; optionally an `error` message type — YAGNI for v1).
   - `"pass"`: `_consecutive_passes += 1`, refill nothing, `_check_end_game_online()`, `_broadcast()`.
   - `"exchange"`: `_bag.exchange(letters)` on the authoritative bag, refill guest rack, `_check_end_game_online()`, `_broadcast()`.
   - `"rematch"`: `_start_online_game()` again (fresh `GameSession`), `_broadcast()`.
6. **Guest — actions:** `_on_submit` (validated locally first for UX), `_on_pass`, `_on_exchange` in online mode → `Net.send_action({type, ...})`, then `_state = WAITING`, `_my_turn = false`, `_update_display()`. Guest never mutates authoritative state.
7. **Both — state received:** `_on_net_state(state)`: `var s := GameSession.from_dict_for_player(state, me)`; restore `_board`, `_bag` as a **shadow** (an empty `TileBag` — never drawn from), `_human_rack` = `s.racks[me]`, opponent rack = `s.racks[1 - me]`, scores, passes, `_my_turn = (s.turn == me)`, `_state = HUMAN_TURN if _my_turn else WAITING`, `_update_display()`. If `s.game_over` → `_end_game_online()`.
8. **No saves online:** guard `_assign_save_slot`/`_auto_save`/`SaveManager.delete_save` with `if not _online_mode`; `_end_game_online()` skips slot deletion, sets `_state = GAME_OVER`, shows `game_overlay.show_scores(...)`.
9. **Disconnect:** `_on_net_disconnect()` → `_set_status("Opponent disconnected")`, disable input, `Net.teardown()`, return to MainMenu after ~1.5 s. `_exit_tree()` → `Net.teardown()`.
10. **Labels:** in `_update_display()`, when `_online_mode`, `%AIScore.text = "Opponent: %d"`.
11. **Rematch:** `game_overlay.play_again_pressed` in online mode → guest sends `{type:"rematch"}` via `Net.send_action`; host restarts. (Host's own Play Again also restarts directly.)

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_game_online.gd` (sync-contract tests; integration covered in Milestone 5):

```gdscript
extends GutTest

const GameSession = preload("res://scripts/game/GameSession.gd")

func test_host_snapshot_guest_restore_roundtrip():
	var host := GameSession.new()
	host.new_game()
	host.board.place_tile(7, 7, "A")
	host.turn = GameSession.Player.P1
	var payload := host.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(payload, GameSession.Player.P1)
	assert_true(guest.board.is_occupied(7, 7))
	assert_eq(guest.bag_pool, [], "guest never holds bag")
	assert_eq(guest.racks[GameSession.Player.P1], host.racks[GameSession.Player.P1])
	assert_eq(guest.turn, GameSession.Player.P1)

func test_guest_turn_render_when_its_not_your_turn():
	var s := GameSession.new()
	s.new_game()
	s.turn = GameSession.Player.P0  # host's turn
	var payload := s.to_dict_for_player(GameSession.Player.P1)
	var guest := GameSession.from_dict_for_player(payload, GameSession.Player.P1)
	assert_eq(guest.turn, GameSession.Player.P0)
	# (mirrors Game._on_net_state: _my_turn = (s.turn == me))
	var me := GameSession.Player.P1
	assert_false(guest.turn == me)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: new tests pass against Milestone-0 `GameSession`; they pin the contract before the Game.gd wiring.

- [ ] **Step 3: Implement** the online branch in `Game.gd` per the behavior list. Keep every change guarded by `_online_mode` so the VS-AI path stays behavior-identical.

- [ ] **Step 4: Run the full suite + lint**

Run: `make test && make lint`
Expected: all green; no gdlint errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/Game.gd tests/unit/test_game_online.gd
git commit -m "feat: online multiplayer branch in Game.gd"
```

---

## Milestone 5 — End-to-end verification, tooling, docs

**Files:**
- Modify: `Makefile` (add `signal-dev`), `Specifications.md` (document network architecture)

- [ ] **Step 1: Add `make signal-dev`**

In `Makefile`, add under a `# ── Signaling ──` section:

```make
# ── Signaling ───────────────────────────────────────────────────────────────
SIGNAL_DIR ?= tools/webrtc_signaling

signal-dev:
	cd $(SIGNAL_DIR) && deno run --allow-net --unstable-kv server.ts
```

Add `signal-dev` to `.PHONY` and to `help`.

- [ ] **Step 2: Manual loopback test (same machine, two clients)**

1. Run the server: `make signal-dev` (or set `SCRABBLE_SIGNALING_URL` to the deployed URL).
2. Launch instance A: `make run` → Online → Create Room → note code.
3. Launch instance B: `make run` → Online → Join Room → enter code.
4. Assert: both reach the Game scene; host's turn enabled, guest's disabled; host plays a word → guest sees the board update and its turn enable; guest plays → host sees it; pass/exchange work; game-over overlay appears on both; Play Again restarts for both; closing one window shows "Opponent disconnected" on the other.

- [ ] **Step 3: Verify hidden-info invariant**

During step 2, confirm the guest's debugger shows an empty `_bag._pool` and no host rack letters in `GameSession.racks`.

- [ ] **Step 4: Cross-platform verification**

- Export web: `make web`; serve `export/web/` over http(s); verify two browser instances connect via `wss://` signaling.
- Export android: `make android`; sideload APK on two devices; verify `INTERNET` permission present and play works.

- [ ] **Step 5: Update `Specifications.md`** — add a section covering: architecture (Lobby → Net → GameSession), the RPC contract, redaction rules, disconnect/rematch handling, and the signaling server protocol.

- [ ] **Step 6: Final gate**

Run: `make lint && make test`
Expected: all green. Commit:

```bash
git add Makefile Specifications.md
git commit -m "chore: add signal-dev target and document multiplayer architecture"
```

---

## Risks & Caveats (addressed by this plan)

- **IP exposure:** P2P reveals public IPs to the peer — acceptable for trusted friends. STUN-only default; libwebrtc's mDNS host-candidate obfuscation masks LAN IPs; optional TURN stays commented out (symmetric NATs may fail with a friendly error). Privacy note shown in the lobby.
- **Hidden info:** guest never receives host rack letters or bag contents; guest client never materializes a bag pool. Host sees everything (host is authoritative).
- **NAT traversal:** explicit Google STUN; on `STATE_FAILED` the client shows an error. Optional `Metered.ca` TURN free tier documented in `README.md`.
- **GDPR:** no IPs stored/logged; KV room records have a 15-min TTL and are deleted on disconnect; privacy line covers the necessary IP exchange.
- **Deno isolates:** per-room `BroadcastChannel` relays messages across edge isolates; KV is registry-only with TTL. Mailbox fallback documented.
- **Web build:** game page and signaling must share scheme compatibility; `wss://` from an https page is fine.
- **No save pollution:** online games skip SaveManager entirely.
- **Spoofed/out-of-turn actions:** host validates sender id and turn from authoritative state; ignores otherwise.
