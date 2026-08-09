# WebRTC signaling server

Free-tier Deno Deploy signaling server for the Scrabble game's peer-to-peer
matches. It is registry-only: it allocates 6-digit room codes and relays
WebRTC `session` / `candidate` messages between the two players. Game state
never touches this server.

## Local development

Requires the Deno CLI (one-time):

```bash
curl -fsSL https://deno.land/install.sh | sh
```

Run locally:

```bash
cd tools/webrtc_signaling
deno run --allow-net server.ts
```

The `deno.json` enables the `kv` unstable flag automatically. The server
listens on `http://localhost:9080/`; a plain HTTP request returns
`scrabble signaling`, WebSocket upgrades start the signaling session.

Run the test suite:

```bash
cd tools/webrtc_signaling
deno test
```

## Deploy to Deno Deploy (free)

1. Install the Deno CLI if not present (see above).
2. Create a free account at https://dash.deno.com (no credit card).
   Note your project name, e.g. `scrabble-signal`.
3. Deploy:

```bash
cd tools/webrtc_signaling
deno login
deno deploy --project scrabble-signal --allow-net server.ts
```

4. Confirm it responds (non-WebSocket request returns "scrabble signaling"):

```bash
curl https://scrabble-signal.deno.dev/
```

5. The signaling WebSocket endpoint is `wss://scrabble-signal.deno.dev/`.
   Set `SIGNALING_URL` in `scripts/net/SignalingConfig.gd` to it, or export
   the env var `SCRABBLE_SIGNALING_URL` when running the game.

## Protocol

Client → server:

- `{"type":"create","room":optional}` — allocate a room; replies `created`.
- `{"type":"join","room":"123456"}` — join an existing room; replies
  `joined` or `error`.
- `{"type":"session","subtype":"offer"|"answer","sdp":"..."}` — relay to peer.
- `{"type":"candidate","mid":"0","index":0,"sdp":"..."}` — relay to peer.

Server → client:

- `{"type":"created","room":"123456","slot":0}`
- `{"type":"joined","room":"123456","slot":1}`
- `{"type":"session",...}` / `{"type":"candidate",...}` — relayed from peer.
- `{"type":"error","reason":"room_full"|"not_found"}`

Rooms hold at most 2 players, expire 15 minutes after last activity, and are
deleted when either player disconnects.

## Architecture notes

The two sockets of a room relay through the same `room:<code>`
`BroadcastChannel`, so messages written by either Deno Deploy isolate are
delivered to the other. Deno KV only registers the room for the join
handshake and is deleted on disconnect. No IP addresses are logged — only
room codes and message types.

If a free-tier limitation ever breaks cross-isolate `BroadcastChannel`
delivery, the fallback is a mailbox design: host writes its offer to KV,
guest watches with `kv.watch`, answers go back through KV, and the
`kv.watch` stream replaces the broadcast channel.
