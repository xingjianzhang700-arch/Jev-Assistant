import { test } from "node:test";
import assert from "node:assert/strict";
import { read, composer } from "../sites/instagram.js";
import { load, fixtureRect } from "./helpers.js";

test("thread reads title and sides by layout", () => {
  const doc = load("instagram_thread.html");
  assert.deepEqual(read(doc, fixtureRect, "/direct/t/123/"), {
    title: "alex.r",
    messages: [
      { side: "other", text: "are we still on for tonight?" },
      { side: "me", text: "yes! 7pm?" },
      { side: "other", text: "perfect, see you there" },
    ],
  });
  assert.equal(composer(doc).getAttribute("aria-label"), "Message");
});

test("anything outside /direct/t/ is not a chat", () => {
  assert.equal(read(load("instagram_thread.html"), fixtureRect, "/direct/inbox/"), null);
  assert.equal(read(load("instagram_thread.html"), fixtureRect, "/"), null);
});

test("thread without readable messages gives an empty snapshot", () => {
  assert.deepEqual(read(load("instagram_empty_thread.html"), fixtureRect, "/direct/t/123/"),
    { title: null, messages: [] });
});
