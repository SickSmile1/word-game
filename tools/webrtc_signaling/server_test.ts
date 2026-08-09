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
