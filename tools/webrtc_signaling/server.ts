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
    const peer_id = crypto.randomUUID().slice(0, 8);
    const tag = () => `${peer_id}${room ? ` room=${room}` : ""}`;

    const send = (obj: Record<string, unknown>) => {
      const text = JSON.stringify(obj);
      console.log(`[ws] ${tag()} -> send ${text}`);
      socket.send(text);
    };

    const open_channel = (code: string) => {
      channel = new BroadcastChannel(`room:${code}`);
      channel.onmessage = (ev) => {
        const msg = JSON.parse(String(ev.data));
        if (msg.peer === peer_id) return; // ignore our own echo
        console.log(`[ws] ${tag()} -> relay ${String(ev.data)}`);
        socket.send(JSON.stringify(msg));
      };
    };

    socket.onopen = () => console.log(`[ws] ${tag()} open`);

    socket.onmessage = async (ev) => {
      const msg = parse_message(String(ev.data));
      console.log(`[ws] ${tag()} <- recv ${String(ev.data)} (parsed=${msg !== null})`);
      if (!msg) return;

      switch (msg.type) {
        case "create": {
          room = await resolve_room(kv, String(msg.room ?? ""));
          await kv.set(["room", room], { players: 1 }, { expireIn: ROOM_TTL_MS });
          open_channel(room);
          send({ type: "created", room, slot: 0 });
          break;
        }
        case "join": {
          room = String(msg.room);
          const entry = await kv.get(["room", room]);
          if (!entry.value) {
            send({ type: "error", reason: "not_found" });
            break;
          }
          const players = (entry.value as { players: number }).players;
          if (players >= MAX_PLAYERS) {
            send({ type: "error", reason: "room_full" });
            break;
          }
          await kv.set(["room", room], { players: players + 1 }, { expireIn: ROOM_TTL_MS });
          open_channel(room);
          send({ type: "joined", room, slot: players });
          break;
        }
        case "session":
        case "candidate":
          if (channel) {
            channel.postMessage(JSON.stringify({ peer: peer_id, type: msg.type, ...msg }));
          } else {
            console.log(`[ws] ${tag()} <- dropped ${msg.type}: no channel`);
          }
          break;
      }
    };

    socket.onclose = () => {
      console.log(`[ws] ${tag()} close`);
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
