import { test } from "node:test";
import assert from "node:assert/strict";
import { read, composer } from "../sites/snapchat.js";
import { load } from "./helpers.js";

test("thread reads title and data-from sides", () => {
  const doc = load("snapchat_thread.html");
  assert.deepEqual(read(doc), {
    title: "Alex",
    messages: [
      { side: "other", text: "are we still on for tonight?" },
      { side: "me", text: "yes! 7pm?" },
      { side: "other", text: "perfect, see you there" },
    ],
  });
  assert.equal(composer(doc).getAttribute("aria-label"), "Send a Chat");
});

test("friend list is not a chat", () => {
  assert.equal(read(load("snapchat_list.html")), null);
});
