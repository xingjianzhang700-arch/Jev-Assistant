import { test } from "node:test";
import assert from "node:assert/strict";
import { read, composer } from "../sites/gmessages.js";
import { load, fixtureRect } from "./helpers.js";

test("conversation reads title and sides in order", () => {
  const doc = load("gmessages_thread.html");
  assert.deepEqual(read(doc, fixtureRect, "/web/conversations/1"), {
    title: "Mom",
    messages: [
      { side: "other", text: "Did you land?" },
      { side: "me", text: "Just now, waiting for bags" },
      { side: "other", text: "Call me when you're out" },
    ],
  });
  assert.equal(composer(doc).tagName, "TEXTAREA");
});

test("conversation list is not a chat", () => {
  assert.equal(read(load("gmessages_list.html"), fixtureRect, "/web/conversations"), null);
});
