import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  sideByEdges, signature, buildState, judgeBody, rankBody, draftBody,
  parseThree, rankReplies, summarize,
} from "../lib/core.js";

const brain = JSON.parse(readFileSync(new URL("../brain.json", import.meta.url), "utf8"));
const convo = [
  { side: "other", text: "hi" },
  { side: "me", text: "hey!" },
  { side: "other", text: "free tonight?" },
];

test("side by edges, long bubbles keep their side", () => {
  assert.equal(sideByEdges(40, 360, 800), "other");
  assert.equal(sideByEdges(560, 780, 800), "me");
  assert.equal(sideByEdges(40, 700, 800), "other");
  assert.equal(sideByEdges(100, 790, 800), "me");
});

test("state keeps the last 10 and names who spoke last", () => {
  const many = Array.from({ length: 12 }, (_, i) => ({ side: i % 2 ? "me" : "other", text: `m${i}` }));
  const s = buildState(many, "friend");
  assert.equal(s.chat.messages.length, 10);
  assert.deepEqual(s.chat.messages[0], { from: "other", text: "m2" });
  assert.equal(s.chat.latest_from, "me");
  assert.equal(s.chat.relationship, "friend");
});

test("judge body sends the shared question set verbatim", () => {
  const b = judgeBody(brain, "typesafe/jev-1.13", convo, "friend");
  assert.equal(b.model, "typesafe/jev-1.13");
  assert.deepEqual(b.questions, brain.judge_questions);
  assert.equal(Object.keys(b.questions).length, 7);
});

test("rank body asks best_reply over exactly three candidates", () => {
  const b = rankBody(brain, "m", convo, "friend", ["a", "b", "c"]);
  assert.deepEqual(b.questions.best_reply.criteria, { reply_a: "a", reply_b: "b", reply_c: "c" });
  assert.equal(b.questions.best_reply.instructions, brain.rank_instructions);
  assert.equal(b.questions.best_reply.type, "choice");
});

test("draft body fills the shared template with Me/Them lines", () => {
  const b = draftBody(brain, "m", convo, "friend");
  assert.equal(b.messages[0].content, brain.draft_system);
  assert.equal(b.messages[1].content,
    "Relationship: friend\n\nRecent conversation:\nThem: hi\nMe: hey!\nThem: free tonight?\n\nGive 3 candidate replies.");
  assert.equal(b.temperature, 0.8);
});

test("parseThree: JSON array, line fallback, padding", () => {
  assert.deepEqual(parseThree('Sure:\n["a", " b ", "c", "d"]', "F"), ["a", "b", "c"]);
  assert.deepEqual(parseThree("1. yes\n2. no", "F"), ["yes", "no", "F"]);
  assert.deepEqual(parseThree("", "F"), ["F", "F", "F"]);
  assert.deepEqual(parseThree("Sure: []", "F"), ["F", "F", "F"]);
});

test("rankReplies sorts by probability", () => {
  const r = rankReplies({ probabilities: { reply_a: 0.2, reply_b: 0.7, reply_c: 0.1 } }, ["a", "b", "c"]);
  assert.deepEqual(r.map((x) => x.text), ["b", "a", "c"]);
  assert.deepEqual(rankReplies(undefined, ["a", "b", "c"]).map((x) => x.prob), [0, 0, 0]);
});

test("summarize picks the fields the panel shows", () => {
  const s = summarize({
    true_intent: { choice: "casual_chat", confidence: 0.8 },
    danger_level: { score: 1.4 }, she_needs: { choice: "nothing" },
    best_action: { choice: "make_plan" }, should_reply_now: { noul: 0.9 },
    tension_resolved: { noul: 0.95 },
  });
  assert.deepEqual(s, { intent: "casual_chat", intentConfidence: 0.8, risk: 1.4, needs: "nothing",
    bestAction: "make_plan", specificsOk: 0.9, tensionResolved: 0.95 });
});

test("signature changes when the last messages change", () => {
  assert.notEqual(signature(convo), signature([...convo, { side: "other", text: "?" }]));
});
