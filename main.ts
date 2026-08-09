import { serve } from "./tools/webrtc_signaling/server.ts";

const kv = await Deno.openKv();
serve(kv);
