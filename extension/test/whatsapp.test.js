import { test } from "node:test";
import assert from "node:assert/strict";
import { read, composer } from "../sites/whatsapp.js";
import { load } from "./helpers.js";

test("thread reads title and in/out sides", () => {
  const doc = load("whatsapp_thread.html");
  assert.deepEqual(read(doc), {
    title: "Alex",
    messages: [
      { side: "other", text: "are we still on for tonight?" },
      { side: "me", text: "yes! 7pm?" },
      { side: "other", text: "perfect, see you there" },
    ],
  });
  assert.equal(composer(doc).getAttribute("aria-label"), "Type a message");
});

test("chat list is not a chat", () => {
  assert.equal(read(load("whatsapp_list.html")), null);
});

test("open chat with no text gives an empty snapshot", () => {
  assert.deepEqual(read(load("whatsapp_empty_thread.html")), { title: "Alex", messages: [] });
});
