export const MAX_PLAYERS = 2;
export const ROOM_TTL_MS = 15 * 60 * 1000;

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

async function resolve_room(kv: Deno.Kv, requested: string): Promise<string> {
  if (requested) return requested;
  for (let i = 0; i < 10; i++) {
    const candidate = generate_room_code();
    const existing = await kv.get(["room", candidate]);
    if (!existing.value) return candidate;
  }
  throw new Error("could not allocate room");
}

export function serve(kv: Deno.Kv): void {
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
          room = await resolve_room(kv, String(msg.room ?? ""));
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
}

if (import.meta.main) {
  const kv = await Deno.openKv();
  serve(kv);
}
