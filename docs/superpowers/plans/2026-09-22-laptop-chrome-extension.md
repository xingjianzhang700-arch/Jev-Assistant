# Jev for Laptop (Chrome Extension) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put Jev in Chrome on any laptop. It reads the open conversation on Instagram web (`instagram.com/direct`) and Google Messages for web (`messages.google.com`, which carries an Android phone's SMS), shows Jev's read of the chat and 3 ranked replies in Chrome's side panel, and fills the chosen reply into the message box. It never sends.

**Architecture:** A Manifest V3 extension written in plain JavaScript with no build step.
- A content script per site reads the page's DOM and sends a snapshot to the background service worker.
- The worker calls the same two APIs the Android app calls: Jev's `alpha/decisions` for judging and ranking, and an OpenAI-compatible `chat/completions` for drafting. It writes the result into `chrome.storage.session`.
- The side panel renders that result.
- The prompts and question set come from `shared/jev-brain.json`. A Kotlin unit test generates that file from the Android sources and fails if it goes stale, so the tuned wording exists in exactly one place.
- The site readers and the prompt logic are pure ES modules, tested with `node --test` against HTML fixtures.

**Tech Stack:** Chrome MV3 (Chrome 116+ for `sidePanel`), vanilla ES modules, Node 24 `node --test`, `linkedom` (dev only, a DOM for tests), Python 3 sync script, JUnit + `org.json` for the Android-side generator test.

**Spec:** The user's request (2026-09-22): *"I want it to work on mobile and laptop"*, answered as: phone = Android (and iPhone users use the laptop versions), laptop = **Chrome extension + Mac app**. This plan covers the Chrome extension. The Mac app is `2026-09-22-laptop-mac-messages.md`.

**Depends on:** `2026-09-22-english-instagram-sms.md` Tasks 1–6 being done, because Task 1 here reads the English prompts that plan produces.

## Global Constraints

- **Never send.** Never click a send button, dispatch Enter or submit a form. Fill the box and stop.
- **Read the page only.** No calls to Instagram's or Google's private APIs. No reading cookies, IndexedDB or network traffic.
- **Render untrusted text safely.** Message text and titles are rendered with `textContent` only. `innerHTML` is never used with page-derived text.
- **Don't log message content.** `console.*` may log counts and lengths only.
- **Keys:** stored in `chrome.storage.local` (per Chrome profile, on disk and not encrypted). This is weaker than the Android app's encrypted settings; the owner accepted the trade-off when choosing a browser extension. Keys are never logged and never sent anywhere except the configured API URLs.
- **Prompt text comes only from `extension/brain.json`**, which is a synced copy of `shared/jev-brain.json`. Never edit prompts in JS.
- Permissions are the minimum: `storage`, `sidePanel`, host access to `https://openrouter.ai/*`, and content scripts on the two sites. Custom API hosts are requested at runtime through `optional_host_permissions`.
- Git: local commits on branch `english-instagram-sms`. Never push.

## File Structure

**Create**
- `shared/jev-brain.json`: the single source for prompts, questions, defaults and display labels.
- `tools/sync_brain.py`: copies the brain to `extension/brain.json` and generates `mac/Sources/JevCore/Brain.generated.swift` (Mac plan). `--check` fails when either copy is stale.
- `app/src/test/java/com/jev/probe/jev/BrainSyncTest.kt`: generates the brain from Kotlin and verifies it.
- `extension/manifest.json`, `extension/package.json`
- `extension/brain.json` (generated)
- `extension/lib/core.js`: pure: state, request bodies, reply parsing, ranking, summary, side rule.
- `extension/lib/api.js`: `postJson` with retry.
- `extension/sites/gmessages.js`, `extension/sites/instagram.js`: `read(doc, rectOf, path)` and `composer(doc)`.
- `extension/content.js`: glue that watches the page, sends snapshots and handles Fill.
- `extension/background.js`: the analysis pipeline.
- `extension/panel.html`, `extension/panel.js`: side panel UI.
- `extension/options.html`, `extension/options.js`: keys, models, relationship, auto-analyze.
- `extension/test/core.test.js`, `gmessages.test.js`, `instagram.test.js`, `extension/test/helpers.js`
- `extension/test/fixtures/*.html`, `extension/test/fixtures/README.md`

**Modify**
- `app/src/main/java/com/jev/probe/jev/ReplyClient.kt`: move the draft prompt into companion constants.
- `app/build.gradle.kts`: add `testImplementation("org.json:json:20240303")`. The `android.jar` `org.json` is a stub that throws in JVM tests.
- `tools/check_cjk.py`: allowlist the brain copies, since they carry the calibrated questions' example Chinese phrases.
- `README.md`, `CHANGELOG.md`

---

### Task 1: Shared brain, generated from Android

**Files:**
- Modify: `app/src/main/java/com/jev/probe/jev/ReplyClient.kt`
- Modify: `app/build.gradle.kts`
- Create: `app/src/test/java/com/jev/probe/jev/BrainSyncTest.kt`
- Create: `shared/jev-brain.json` (generated, then `labels` added by hand)
- Create: `tools/sync_brain.py`
- Modify: `tools/check_cjk.py` (`ALLOW_FILES`)

**Interfaces:**
- Produces: `shared/jev-brain.json` with these keys:
  `judge_url_default`, `judge_model_default`, `reply_url_default`, `reply_model_default`, `default_relationship` (strings);
  `judge_questions` (object, sent verbatim as the decisions `questions`);
  `rank_instructions`, `draft_system`, `draft_user_template` (with `{relationship}` and `{conversation}` placeholders), `fallback_reply` (strings);
  `labels` (object: `intent`, `needs`, `action` → `{key: English label}`).
- Produces: Kotlin `ReplyClient.DRAFT_SYSTEM`, `ReplyClient.FALLBACK_REPLY`, `ReplyClient.draftUser(relationship: String, convo: String): String`.
- Produces: `python3 tools/sync_brain.py [--check]`.

- [ ] **Step 1: Expose the draft prompt as constants in `ReplyClient.kt`**

Add a companion object holding the exact text Plan 1 Task 4 wrote, and use it:

```kotlin
    companion object {
        /** Shared with the laptop clients via shared/jev-brain.json (see BrainSyncTest). */
        const val DRAFT_SYSTEM =
            "You suggest replies in an instant-messaging chat. Output only a JSON array " +
                "containing exactly 3 candidate replies. Use three different strategies (for example: " +
                "one steady and receptive, one with a concrete action or commitment, one short and low-key). " +
                "Each under 40 words, casual and natural, like a real person texting. " +
                "Write in the same language the other person is writing in. " +
                "No explanations, nothing outside the JSON array."

        const val FALLBACK_REPLY = "One sec, let me check."

        fun draftUser(relationship: String, convo: String): String =
            "Relationship: ${relationship}\n\nRecent conversation:\n${convo}\n\nGive 3 candidate replies."
    }
```

In `draft`: `val sys = DRAFT_SYSTEM` and `val user = knowledgeBlock(relationship, ctx) + draftUser(relationship, convo)`. In `parseThree`: replace both `"One sec, let me check."` literals with `FALLBACK_REPLY`.

- [ ] **Step 2: Real `org.json` for JVM tests**

`app/build.gradle.kts` dependencies:

```kotlin
    testImplementation("org.json:json:20240303")
```

- [ ] **Step 3: Write the generator test**

`app/src/test/java/com/jev/probe/jev/BrainSyncTest.kt`:

```kotlin
package com.jev.probe.jev

import com.jev.probe.core.Prefs
import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * shared/jev-brain.json must equal what the Android sources say. The laptop
 * clients read that file, so this is what keeps all three on one wording.
 * Regenerate: UPDATE_BRAIN=1 ./gradlew --no-daemon :app:testDebugUnitTest --tests '*BrainSyncTest'
 * Keys not generated here (e.g. "labels") are kept as they are.
 */
class BrainSyncTest {
    private val file = File("../shared/jev-brain.json")   // test cwd is app/

    private fun expected(): JSONObject = JSONObject()
        .put("judge_url_default", Prefs.DEFAULT_JUDGE_BASE_OPENROUTER + "/alpha/decisions")
        .put("judge_model_default", Prefs.DEFAULT_JUDGE_MODEL_OPENROUTER)
        .put("reply_url_default", Prefs.DEFAULT_REPLY_BASE + "/chat/completions")
        .put("reply_model_default", Prefs.DEFAULT_REPLY_MODEL)
        .put("default_relationship", Prefs.DEFAULT_REL)
        .put("judge_questions", JevQuestions.judge())
        .put("rank_instructions", JevQuestions.rankQuestion(listOf("a", "b", "c"))
            .getJSONObject("best_reply").getString("instructions"))
        .put("draft_system", ReplyClient.DRAFT_SYSTEM)
        .put("draft_user_template", ReplyClient.draftUser("{relationship}", "{conversation}"))
        .put("fallback_reply", ReplyClient.FALLBACK_REPLY)

    private fun same(a: Any?, b: Any?): Boolean = if (a is JSONObject) a.similar(b) else a == b

    @Test fun sharedBrainMatchesAndroid() {
        val want = expected()
        if (System.getenv("UPDATE_BRAIN") == "1") {
            val merged = if (file.exists()) JSONObject(file.readText()) else JSONObject()
            want.keys().forEach { merged.put(it, want.get(it)) }
            file.parentFile.mkdirs()
            file.writeText(merged.toString(2) + "\n")
        }
        assertTrue("missing ${file.path}; run with UPDATE_BRAIN=1", file.exists())
        val have = JSONObject(file.readText())
        want.keys().forEach { k ->
            assertTrue("shared/jev-brain.json '$k' is stale; run with UPDATE_BRAIN=1", same(want.get(k), have.opt(k)))
        }
    }
}
```

- [ ] **Step 4: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests '*BrainSyncTest'`
Expected: FAIL with `missing ../shared/jev-brain.json; run with UPDATE_BRAIN=1`.

- [ ] **Step 5: Generate, then verify**

```bash
UPDATE_BRAIN=1 ./gradlew --no-daemon :app:testDebugUnitTest --tests '*BrainSyncTest'
./gradlew :app:testDebugUnitTest --tests '*BrainSyncTest'
```

Expected: both PASS, and `shared/jev-brain.json` exists with a 7-key `judge_questions`.

- [ ] **Step 6: Add the display labels by hand**

Add this top-level key to `shared/jev-brain.json`. The strings are the Plan 1 glossary.

```json
  "labels": {
    "intent": {"confirm_you_care": "checking you care", "vent_anger": "venting", "request_action": "wants action",
               "seek_explanation": "wants an explanation", "casual_chat": "casual chat", "close_topic": "topic closed"},
    "needs": {"apology": "an apology", "action": "a concrete action", "explanation": "an explanation",
              "care": "your care", "nothing": "(nothing)"},
    "action": {"check_history": "check history", "apologize": "apologize first", "give_commitment": "commit",
               "explain": "explain", "acknowledge": "acknowledge", "say_less": "say less", "make_plan": "make a plan"}
  }
```

Re-run `./gradlew :app:testDebugUnitTest --tests '*BrainSyncTest'`. Expected: PASS (labels aren't generated, so they're left alone).

- [ ] **Step 7: Write the sync script**

`tools/sync_brain.py`:

```python
#!/usr/bin/env python3
"""Copy shared/jev-brain.json to every client that embeds it.

  python3 tools/sync_brain.py          write the copies
  python3 tools/sync_brain.py --check  exit 1 if any copy is stale

A client whose directory does not exist yet is skipped.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "shared" / "jev-brain.json"


def targets(text):
    swift = (
        "// Generated by tools/sync_brain.py from shared/jev-brain.json. Do not edit.\n"
        'let brainJSONText = #"""\n' + text.rstrip("\n") + '\n"""#\n'
    )
    return {
        ROOT / "extension" / "brain.json": text,
        ROOT / "mac" / "Sources" / "JevCore" / "Brain.generated.swift": swift,
    }


def main(argv):
    text = SRC.read_text(encoding="utf-8")
    stale = []
    for path, content in targets(text).items():
        if not path.parent.exists():
            continue
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == content:
            continue
        if "--check" in argv:
            stale.append(str(path.relative_to(ROOT)))
        else:
            path.write_text(content, encoding="utf-8")
            print(f"wrote {path.relative_to(ROOT)}")
    if stale:
        print("stale (run tools/sync_brain.py): " + ", ".join(stale), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 8: Allowlist the brain copies in the CJK checker**

In `tools/check_cjk.py`, add to `ALLOW_FILES`:

```python
    "shared/jev-brain.json",
    "extension/brain.json",
    "mac/Sources/JevCore/Brain.generated.swift",
```

(They carry the calibrated question text, which includes a few Chinese example phrases.)

- [ ] **Step 9: Checks pass, then commit**

Run: `./gradlew :app:testDebugUnitTest && python3 tools/sync_brain.py --check && python3 tools/check_cjk.py`
Expected: all exit 0. `sync_brain --check` passes trivially because neither client directory exists yet.

```bash
git add app shared tools
git commit -m "feat: shared/jev-brain.json generated from Android prompts, with sync script"
```

---

### Task 2: Extension skeleton and pure core logic

**Files:**
- Create: `extension/package.json`, `extension/manifest.json`, `extension/lib/core.js`, `extension/test/core.test.js`
- Generate: `extension/brain.json`

**Interfaces:**
- Consumes: `shared/jev-brain.json` keys from Task 1.
- Produces (`extension/lib/core.js`, all pure):
  - `sideByEdges(left, right, width) → "me" | "other"`
  - `signature(messages) → string`
  - `buildState(messages, relationship) → object`
  - `judgeBody(brain, model, messages, relationship) → object`
  - `rankBody(brain, model, messages, relationship, candidates) → object`
  - `draftBody(brain, model, messages, relationship) → object`
  - `parseThree(content, fallback) → string[3]`
  - `rankReplies(bestReply, candidates) → [{text, prob}]` (sorted by prob, highest first)
  - `summarize(answers) → {intent, intentConfidence, risk, needs, bestAction, specificsOk, tensionResolved}`
  - Message shape everywhere: `{side: "me"|"other", text: string}`.

- [ ] **Step 1: Package files and brain copy**

`extension/package.json`:

```json
{
  "name": "jev-assistant-extension",
  "private": true,
  "type": "module",
  "scripts": { "test": "node --test" },
  "devDependencies": { "linkedom": "^0.18.0" }
}
```

```bash
cd extension && npm install && cd ..
python3 tools/sync_brain.py
echo "node_modules/" >> .gitignore
```

Expected: `wrote extension/brain.json`.

`extension/manifest.json`:

```json
{
  "manifest_version": 3,
  "name": "Jev Assistant",
  "version": "1.4.0",
  "description": "Reads the open Instagram or Google Messages chat and suggests replies. Never sends.",
  "minimum_chrome_version": "116",
  "permissions": ["storage", "sidePanel"],
  "host_permissions": ["https://openrouter.ai/*"],
  "optional_host_permissions": ["https://*/*"],
  "background": { "service_worker": "background.js", "type": "module" },
  "side_panel": { "default_path": "panel.html" },
  "action": { "default_title": "Jev Assistant" },
  "options_page": "options.html",
  "content_scripts": [
    { "matches": ["https://www.instagram.com/*", "https://messages.google.com/*"], "js": ["content.js"] }
  ],
  "web_accessible_resources": [
    { "resources": ["lib/*.js", "sites/*.js"],
      "matches": ["https://www.instagram.com/*", "https://messages.google.com/*"] }
  ]
}
```

- [ ] **Step 2: Write the failing tests**

`extension/test/core.test.js`:

```js
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd extension && npm test`
Expected: FAIL, `Cannot find module .../lib/core.js`.

- [ ] **Step 4: Implement `extension/lib/core.js`**

```js
// Pure logic shared by the background worker, the site readers and the tests.
// No chrome.* and no DOM here. Prompt text comes only from brain.json.

/** "me" when the bubble hugs the right edge more than the left. */
export function sideByEdges(left, right, width) {
  return width - right < left ? "me" : "other";
}

export function signature(messages) {
  return messages.slice(-6).map((m) => `${m.side}:${m.text}`).join("|");
}

export function buildState(messages, relationship) {
  const last = messages.slice(-10);
  return {
    chat: {
      relationship,
      messages: last.map((m) => ({ from: m.side, text: m.text })),
      latest_from: last.at(-1)?.side ?? "other",
    },
  };
}

export function judgeBody(brain, model, messages, relationship) {
  return { model, state: buildState(messages, relationship), questions: brain.judge_questions };
}

export function rankBody(brain, model, messages, relationship, candidates) {
  const [a, b, c] = candidates;
  return {
    model,
    state: buildState(messages, relationship),
    questions: {
      best_reply: {
        type: "choice",
        instructions: brain.rank_instructions,
        criteria: { reply_a: a, reply_b: b, reply_c: c },
      },
    },
  };
}

export function draftBody(brain, model, messages, relationship) {
  const conversation = messages.slice(-10)
    .map((m) => (m.side === "me" ? "Me" : "Them") + ": " + m.text).join("\n");
  const user = brain.draft_user_template
    .replace("{relationship}", () => relationship)
    .replace("{conversation}", () => conversation);
  return {
    model,
    temperature: 0.8,
    messages: [
      { role: "system", content: brain.draft_system },
      { role: "user", content: user },
    ],
  };
}

/** Same rules as Android's ReplyClient.parseThree. */
export function parseThree(content, fallback) {
  let out = [];
  const a = content.indexOf("["), b = content.lastIndexOf("]");
  if (a >= 0 && b > a) {
    try { out = JSON.parse(content.slice(a, b + 1)).map((s) => String(s).trim()); } catch { out = []; }
  }
  if (out.length === 0) {
    out = content.split("\n").map((l) => l.trim().replace(/^[-*123. "]+/, "")).filter(Boolean);
  }
  out = out.slice(0, 3);
  while (out.length < 3) out.push(fallback);
  return out;
}

export function rankReplies(bestReply, candidates) {
  const keys = ["reply_a", "reply_b", "reply_c"];
  const p = bestReply?.probabilities ?? {};
  return candidates
    .map((text, i) => ({ text, prob: Number(p[keys[i]] ?? 0) }))
    .sort((x, y) => y.prob - x.prob);
}

export function summarize(a) {
  return {
    intent: a.true_intent?.choice ?? null,
    intentConfidence: a.true_intent?.confidence ?? null,
    risk: a.danger_level?.score ?? null,
    needs: a.she_needs?.choice ?? null,
    bestAction: a.best_action?.choice ?? null,
    specificsOk: a.should_reply_now?.noul ?? null,
    tensionResolved: a.tension_resolved?.noul ?? null,
  };
}
```

(`replace` with a function callback means a `$` in the user's text is never read as a replacement pattern.)

- [ ] **Step 5: Run to verify it passes**

Run: `cd extension && npm test`
Expected: 9 tests pass.

- [ ] **Step 6: Commit**

```bash
git add extension .gitignore
git commit -m "feat(extension): MV3 skeleton and tested core prompt logic"
```

---

### Task 3: Capture real page structure (HUMAN + agent)

Instagram's class names are machine-generated and change often, so the readers key off ARIA roles and custom element names. These fixtures confirm them.

**Files:**
- Create: `extension/test/fixtures/instagram_thread_real.html`, `instagram_inbox_real.html`, `gmessages_thread_real.html`, `gmessages_list_real.html`
- Create: `extension/test/fixtures/README.md`

**Interfaces:**
- Produces: fixtures in which every element carries `data-jev-rect="left,top,right,bottom"` (from the live layout); a README listing, for each thread fixture, the URL path, and the messages top to bottom with sides.

- [ ] **Step 1: For each of the 4 pages, open it in Chrome with a TEST conversation, open DevTools → Console, paste and run:**

```js
(() => {
  const root = document.querySelector('[role="main"]') ?? document.body;
  const els = [...root.querySelectorAll("*")];
  for (const el of els) {
    const r = el.getBoundingClientRect();
    el.setAttribute("data-jev-rect", [r.left, r.top, r.right, r.bottom].map(Math.round).join(","));
  }
  const clone = root.cloneNode(true);
  for (const el of els) el.removeAttribute("data-jev-rect");
  clone.querySelectorAll("script,style,svg,img,video,picture,link,noscript").forEach((n) => n.remove());
  copy("<!doctype html><html><body>" + clone.outerHTML + "</body></html>");
  console.log("Copied page structure to the clipboard.");
})();
```

Paste each result into the matching fixture file. These files get committed, so **use a test conversation**, and change any real names or text before committing. Leave the tags and attributes alone.

- [ ] **Step 2: Confirm the selectors**

```bash
cd extension/test/fixtures
grep -o 'role="grid"[^>]*aria-label="[^"]*"' instagram_thread_real.html | head -3
grep -c 'role="row"' instagram_thread_real.html
grep -o 'role="textbox"[^>]*' instagram_thread_real.html | head -2
grep -o '<mws-[a-z-]*' gmessages_thread_real.html | sort | uniq -c | sort -rn | head -20
grep -o 'is-outgoing="[a-z]*"' gmessages_thread_real.html | sort | uniq -c
```

Tasks 4–5 expect:
- **Instagram:** `div[role="grid"][aria-label^="Messages in conversation with"]`, `[role="row"]` per message with its text in `div[dir="auto"]`, and a composer `div[role="textbox"][contenteditable="true"]`.
- **Google Messages:** `mws-message-wrapper[is-outgoing]` per message, text in `.text-msg`, composer `mws-message-compose textarea`, title `mws-conversation-header h2`.

Write down any difference in the README. Tasks 4–5 then use the observed selectors. If Google Messages turns out to render inside shadow roots (the clone would show `mws-*` tags with no content), stop and report. The reader would then need `element.shadowRoot` traversal, and the plan changes.

- [ ] **Step 3: README**

```markdown
# Web fixtures

| Page | Date captured | Selectors confirmed (or what differed) |
|---|---|---|
| Instagram thread | ... | ... |
| Google Messages thread | ... | ... |

## instagram_thread_real.html — path /direct/t/<id>/
1. other: "..."
2. me: "..."
```

- [ ] **Step 4: Commit**

```bash
git add extension/test/fixtures
git commit -m "test(extension): real Instagram and Google Messages page fixtures"
```

---

### Task 4: Google Messages web reader

**Files:**
- Create: `extension/sites/gmessages.js`, `extension/test/helpers.js`, `extension/test/gmessages.test.js`
- Create: `extension/test/fixtures/gmessages_thread.html`, `gmessages_list.html`

**Interfaces:**
- Consumes: nothing from `core.js`, because the page marks outgoing messages itself.
- Produces: `read(doc, rectOf, path) → null | {title, messages}` and `composer(doc) → Element | null`. These are the same exports `sites/instagram.js` has, so `content.js` treats both sites alike. `null` = not in a conversation; `messages: []` = in one but nothing readable.
- Produces (test helper): `load(name) → Document` and `fixtureRect(el) → {left, top, right, bottom, width, height}`.

- [ ] **Step 1: Fixtures and helper**

`extension/test/fixtures/gmessages_thread.html`:

```html
<!doctype html><html><body>
<mws-conversation-header><h2>Mom</h2></mws-conversation-header>
<mws-messages-list>
  <mws-message-wrapper is-outgoing="false"><mws-text-message-part><div class="text-msg">Did you land?</div></mws-text-message-part></mws-message-wrapper>
  <mws-message-wrapper is-outgoing="true"><mws-text-message-part><div class="text-msg">Just now, waiting for bags</div></mws-text-message-part></mws-message-wrapper>
  <mws-message-wrapper is-outgoing="false"><mws-text-message-part><div class="text-msg">Call me when you're out</div></mws-text-message-part></mws-message-wrapper>
</mws-messages-list>
<mws-message-compose><textarea></textarea></mws-message-compose>
</body></html>
```

`extension/test/fixtures/gmessages_list.html`:

```html
<!doctype html><html><body>
<mws-conversations-list>
  <mws-conversation-list-item><span>Mom</span><span>Call me when you're out</span></mws-conversation-list-item>
</mws-conversations-list>
</body></html>
```

`extension/test/helpers.js`:

```js
import { readFileSync } from "node:fs";
import { parseHTML } from "linkedom";

export function load(name) {
  const html = readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8");
  return parseHTML(html).document;
}

/** Layout for fixtures: the data-jev-rect the capture snippet recorded. */
export function fixtureRect(el) {
  const [left, top, right, bottom] = (el.getAttribute("data-jev-rect") ?? "0,0,0,0").split(",").map(Number);
  return { left, top, right, bottom, width: right - left, height: bottom - top };
}
```

- [ ] **Step 2: Write the failing tests**

`extension/test/gmessages.test.js`:

```js
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd extension && npm test`
Expected: FAIL, `Cannot find module .../sites/gmessages.js`.

- [ ] **Step 4: Implement `extension/sites/gmessages.js`**

```js
// Google Messages for web (messages.google.com). Custom elements mark each
// message and whether it is outgoing, so no layout is needed.
// Selectors confirmed against test/fixtures (see its README).

export function composer(doc) {
  return doc.querySelector("mws-message-compose textarea");
}

export function read(doc) {
  if (!composer(doc)) return null;
  const messages = [];
  for (const w of doc.querySelectorAll("mws-message-wrapper")) {
    const text = (w.querySelector(".text-msg")?.textContent ?? "").trim();
    if (text) messages.push({ side: w.getAttribute("is-outgoing") === "true" ? "me" : "other", text });
  }
  const title = doc.querySelector("mws-conversation-header h2")?.textContent.trim() || null;
  return { title, messages };
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd extension && npm test`
Expected: core 9 + gmessages 2 pass.

- [ ] **Step 6: Real-fixture regression tests**

Append to `gmessages.test.js`, copying the expected list from the fixtures README:

```js
test("real conversation fixture", () => {
  const snap = read(load("gmessages_thread_real.html"), fixtureRect, "/web/conversations/1");
  assert.deepEqual(snap.messages, [
    { side: "other", text: "<first message from README>" },
    { side: "me", text: "<second message from README>" },
    // ... every message in the README, in order
  ]);
});

test("real list fixture", () => {
  assert.equal(read(load("gmessages_list_real.html"), fixtureRect, "/web/conversations"), null);
});
```

Replace each `<...>` with the literal text from the README. Run `npm test`. Expected: all pass. If a real test fails, fix the selectors, not the test.

- [ ] **Step 7: Commit**

```bash
git add extension
git commit -m "feat(extension): read Google Messages for web conversations"
```

---

### Task 5: Instagram web reader

**Files:**
- Create: `extension/sites/instagram.js`, `extension/test/instagram.test.js`
- Create: `extension/test/fixtures/instagram_thread.html`, `instagram_empty_thread.html`

**Interfaces:**
- Consumes: `sideByEdges` from `../lib/core.js`; `load` and `fixtureRect` from `test/helpers.js`.
- Produces: `read(doc, rectOf, path)` and `composer(doc)`, the same contract as Task 4.

- [ ] **Step 1: Fixtures**

`extension/test/fixtures/instagram_thread.html`:

```html
<!doctype html><html><body>
<div role="main" data-jev-rect="0,0,1200,900">
  <div role="grid" aria-label="Messages in conversation with alex.r" data-jev-rect="400,80,1200,820">
    <div role="row" data-jev-rect="400,100,1200,140"><div dir="auto" data-jev-rect="440,100,760,140">are we still on for tonight?</div></div>
    <div role="row" data-jev-rect="400,150,1200,190"><div dir="auto" data-jev-rect="960,150,1180,190">yes! 7pm?</div></div>
    <div role="row" data-jev-rect="400,200,1200,240"><div dir="auto" data-jev-rect="440,200,700,240">perfect, see you there</div></div>
  </div>
  <div role="textbox" contenteditable="true" aria-label="Message" data-jev-rect="420,840,1180,880"></div>
</div>
</body></html>
```

`extension/test/fixtures/instagram_empty_thread.html`:

```html
<!doctype html><html><body>
<div role="main" data-jev-rect="0,0,1200,900">
  <div role="textbox" contenteditable="true" aria-label="Message" data-jev-rect="420,840,1180,880"></div>
</div>
</body></html>
```

- [ ] **Step 2: Write the failing tests**

`extension/test/instagram.test.js`:

```js
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd extension && npm test`
Expected: FAIL, `Cannot find module .../sites/instagram.js`.

- [ ] **Step 4: Implement `extension/sites/instagram.js`**

```js
// Instagram web Direct (instagram.com/direct/t/<id>/). Class names are
// generated, so this keys off ARIA roles and layout only.
// Selectors confirmed against test/fixtures (see its README).
import { sideByEdges } from "../lib/core.js";

const GRID = 'div[role="grid"][aria-label^="Messages in conversation"]';

export function composer(doc) {
  return doc.querySelector('div[role="textbox"][contenteditable="true"]');
}

export function read(doc, rectOf, path) {
  if (!/^\/direct\/t\//.test(path) || !composer(doc)) return null;
  const grid = doc.querySelector(GRID);
  if (!grid) return { title: null, messages: [] };
  const g = rectOf(grid);
  const title = (grid.getAttribute("aria-label") ?? "")
    .replace(/^Messages in conversation with\s*/, "").trim() || null;
  const messages = [];
  for (const row of grid.querySelectorAll('[role="row"]')) {
    const el = row.querySelector('div[dir="auto"]');
    const text = el?.textContent.trim();
    if (!text) continue;
    const r = rectOf(el);
    messages.push({ side: sideByEdges(r.left - g.left, r.right - g.left, g.width), text });
  }
  return { title, messages };
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd extension && npm test`
Expected: all pass (core 9, gmessages 4, instagram 3).

- [ ] **Step 6: Real-fixture regression tests**

Append the same two tests as Task 4 Step 6, using `instagram_thread_real.html` (with the path from the README) and `instagram_inbox_real.html` (path `/direct/inbox/`, expecting `null`), with the expected messages copied from the README. Run `npm test`. Expected: all pass. If one fails, fix the selectors, not the test.

- [ ] **Step 7: Commit**

```bash
git add extension
git commit -m "feat(extension): read Instagram web Direct threads"
```

---

### Task 6: Background pipeline, content script, side panel, options

This part is glue on top of Chrome APIs, so it isn't unit-tested. It's verified by loading the extension in Step 7.

**Files:**
- Create: `extension/lib/api.js`, `extension/background.js`, `extension/content.js`, `extension/panel.html`, `extension/panel.js`, `extension/options.html`, `extension/options.js`

**Interfaces:**
- Consumes: everything from Tasks 2, 4 and 5.
- Message protocol:
  - content → background: `{type: "snapshot", snapshot: {title, messages, sig, latestFrom}}`
  - panel → background: `{type: "analyzeNow"}`
  - panel → content (via `chrome.tabs.sendMessage`): `{type: "fill", text}` → reply `{ok: boolean}`
- Session storage: `sig` (last seen), `snap` (last snapshot + `tabId`), `view` (what the panel renders: `{title, status?, error?, summary?, replies?}`).

- [ ] **Step 1: `extension/lib/api.js`**

```js
// POST JSON. Retries 429/529 twice with backoff. Keys are never logged.
export async function postJson(url, key, body) {
  const headers = { Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
  if (url.includes("openrouter.ai")) {
    headers["HTTP-Referer"] = "https://jev-assistant.local";
    headers["X-Title"] = "Jev Assistant";
  }
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
    if ((res.status === 429 || res.status === 529) && attempt < 2) {
      await new Promise((r) => setTimeout(r, 1000 << attempt));
      continue;
    }
    const text = await res.text();
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 120)}`);
    return JSON.parse(text);
  }
}
```

- [ ] **Step 2: `extension/background.js`**

```js
import { judgeBody, rankBody, draftBody, parseThree, rankReplies, summarize } from "./lib/core.js";
import { postJson } from "./lib/api.js";

const brainP = fetch(chrome.runtime.getURL("brain.json")).then((r) => r.json());
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });

async function settings() {
  const brain = await brainP;
  const s = await chrome.storage.local.get(
    ["judgeKey", "replyKey", "relationship", "judgeUrl", "judgeModel", "replyUrl", "replyModel", "auto"]);
  return {
    brain,
    judgeKey: s.judgeKey ?? "",
    replyKey: s.replyKey || s.judgeKey || "",
    relationship: s.relationship || brain.default_relationship,
    judgeUrl: s.judgeUrl || brain.judge_url_default,
    judgeModel: s.judgeModel || brain.judge_model_default,
    replyUrl: s.replyUrl || brain.reply_url_default,
    replyModel: s.replyModel || brain.reply_model_default,
    auto: s.auto ?? true,
  };
}

const show = (view) => chrome.storage.session.set({ view });

async function analyze(snap) {
  const cfg = await settings();
  if (!cfg.judgeKey) return show({ title: snap.title, error: "No Judge API key set. Add one in the extension options." });
  await show({ title: snap.title, status: "Analyzing…" });
  const { brain, relationship: rel } = cfg;
  try {
    const [judged, candidates] = await Promise.all([
      postJson(cfg.judgeUrl, cfg.judgeKey, judgeBody(brain, cfg.judgeModel, snap.messages, rel)),
      postJson(cfg.replyUrl, cfg.replyKey, draftBody(brain, cfg.replyModel, snap.messages, rel))
        .then((r) => parseThree(r.choices?.[0]?.message?.content ?? "", brain.fallback_reply)),
    ]);
    const ranked = await postJson(cfg.judgeUrl, cfg.judgeKey,
      rankBody(brain, cfg.judgeModel, snap.messages, rel, candidates));
    await show({
      title: snap.title,
      summary: summarize(judged.answers ?? {}),
      replies: rankReplies(ranked.answers?.best_reply, candidates),
    });
  } catch (e) {
    await show({ title: snap.title, error: String(e?.message ?? e) });
  }
}

async function onSnapshot(snapshot, tabId) {
  const { sig } = await chrome.storage.session.get("sig");
  if (snapshot.sig === sig) return;
  const snap = { ...snapshot, tabId };
  await chrome.storage.session.set({ sig: snapshot.sig, snap });
  if (snap.messages.length === 0) return show({ title: snap.title, status: "Can't read this chat's text." });
  const { auto } = await settings();
  if (snap.latestFrom === "other" && auto) return analyze(snap);
  return show({ title: snap.title, status: "Press Analyze when you want suggestions." });
}

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === "snapshot" && sender.tab) onSnapshot(msg.snapshot, sender.tab.id);
  if (msg.type === "analyzeNow") chrome.storage.session.get("snap").then(({ snap }) => snap && analyze(snap));
});
```

- [ ] **Step 3: `extension/content.js`**

```js
// Classic content script. Pulls the ES modules in through dynamic import
// (they are listed in web_accessible_resources). Never sends a message.
(async () => {
  const url = (p) => chrome.runtime.getURL(p);
  const { signature } = await import(url("lib/core.js"));
  const site = await import(url(location.host === "messages.google.com" ? "sites/gmessages.js" : "sites/instagram.js"));
  const rectOf = (el) => el.getBoundingClientRect();
  let timer = 0;
  let lastSig = null;

  function capture() {
    const snap = site.read(document, rectOf, location.pathname);
    if (!snap) return;
    const sig = (snap.title ?? "") + "#" + signature(snap.messages);
    if (sig === lastSig) return;
    lastSig = sig;
    chrome.runtime.sendMessage({
      type: "snapshot",
      snapshot: { ...snap, sig, latestFrom: snap.messages.at(-1)?.side ?? null },
    });
  }

  // Instagram and Google Messages are single-page apps: watch the DOM, debounce bursts.
  new MutationObserver(() => { clearTimeout(timer); timer = setTimeout(capture, 800); })
    .observe(document.body, { childList: true, subtree: true, characterData: true });
  capture();

  chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
    if (msg.type === "fill") reply({ ok: fill(site.composer(document), msg.text) });
  });

  /** Put text in the box. Never presses Enter, never clicks send. */
  function fill(box, text) {
    if (!box) return false;
    box.focus();
    if (box instanceof HTMLTextAreaElement || box instanceof HTMLInputElement) {
      // The native setter, so React/Angular see the change.
      Object.getOwnPropertyDescriptor(Object.getPrototypeOf(box), "value").set.call(box, text);
      box.dispatchEvent(new Event("input", { bubbles: true }));
      return box.value === text;
    }
    // contenteditable (Instagram's rich-text editor): insertText keeps its state in sync.
    document.execCommand("selectAll", false);
    document.execCommand("insertText", false, text);
    return box.textContent.includes(text);
  }
})();
```

- [ ] **Step 4: Side panel**

`extension/panel.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Jev Assistant</title>
  <style>
    :root { color-scheme: light dark; font: 14px/1.4 system-ui, sans-serif; }
    body { margin: 0; padding: 12px; }
    h1 { font-size: 15px; margin: 0 0 8px; }
    .sub { opacity: .7; font-size: 12px; }
    .err { color: #dc2626; }
    .reply { border: 1px solid #8884; border-radius: 8px; padding: 8px; margin: 8px 0; }
    .reply button { margin-right: 6px; }
  </style>
</head>
<body>
  <h1 id="title">Jev</h1>
  <div id="body" class="sub">Open an Instagram or Google Messages conversation.</div>
  <p><button id="analyze">Analyze</button> <span id="note" class="sub"></span></p>
  <script type="module" src="panel.js"></script>
</body>
</html>
```

`extension/panel.js`:

```js
// Renders chrome.storage.session "view". Page-derived text only ever goes in via textContent.
const brain = await fetch("brain.json").then((r) => r.json());
const $ = (id) => document.getElementById(id);
const label = (group, key) => brain.labels?.[group]?.[key] ?? key;
const el = (tag, text, cls) => { const e = document.createElement(tag); e.textContent = text; if (cls) e.className = cls; return e; };

function render(view) {
  $("title").textContent = view?.title ? `Jev · ${view.title}` : "Jev";
  const body = $("body");
  body.replaceChildren();
  body.className = "";
  if (!view) { body.append(el("div", "Open an Instagram or Google Messages conversation.", "sub")); return; }
  if (view.error) { body.append(el("div", "Something went wrong", "err"), el("div", view.error, "sub")); return; }
  if (view.status) { body.append(el("div", view.status, "sub")); return; }
  const s = view.summary ?? {};
  if (s.intent) body.append(el("div", `Their real intent: ${label("intent", s.intent)}`));
  const bits = [];
  if (s.risk != null) bits.push(`Risk ${Math.round(s.risk)}/9`);
  if (s.needs) bits.push(`Needs ${label("needs", s.needs)}`);
  if (s.bestAction) bits.push(label("action", s.bestAction));
  if (s.specificsOk != null) bits.push(s.specificsOk >= 0.5 ? "OK to give specifics" : "Hold off on specifics");
  if (bits.length) body.append(el("div", bits.join(" · "), "sub"));
  if (s.tensionResolved >= 0.7) body.append(el("div", "✓ Tension resolved", "sub"));
  body.append(el("div", "Suggested replies (ranked by Jev)", "sub"));
  for (const r of view.replies ?? []) {
    const box = el("div", "", "reply");
    box.append(el("div", `${Math.round(r.prob * 100)}%  ${r.text}`));
    const fill = el("button", "Fill");
    fill.onclick = () => fillReply(r.text);
    const copy = el("button", "Copy");
    copy.onclick = () => navigator.clipboard.writeText(r.text).then(() => note("Copied"));
    box.append(fill, copy);
    body.append(box);
  }
}

const note = (t) => { $("note").textContent = t; };

async function fillReply(text) {
  const { snap } = await chrome.storage.session.get("snap");
  let ok = false;
  try { ok = (await chrome.tabs.sendMessage(snap.tabId, { type: "fill", text }))?.ok; } catch { ok = false; }
  if (ok) return note("Filled in. Review it, then send it yourself");
  await navigator.clipboard.writeText(text);
  note("Copied. Click the message box and paste");
}

$("analyze").onclick = () => chrome.runtime.sendMessage({ type: "analyzeNow" });
chrome.storage.session.onChanged.addListener((c) => { if (c.view) render(c.view.newValue); });
render((await chrome.storage.session.get("view")).view);
```

- [ ] **Step 5: Options page**

`extension/options.html`:

```html
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Jev Assistant options</title>
<style>
  :root { color-scheme: light dark; font: 14px/1.4 system-ui, sans-serif; }
  body { max-width: 520px; margin: 24px auto; padding: 0 16px; }
  label { display: block; margin: 12px 0 4px; }
  input, textarea { width: 100%; box-sizing: border-box; }
</style></head>
<body>
  <h1>Jev Assistant</h1>
  <label for="judgeKey">Judge API key (OpenRouter)</label><input id="judgeKey" type="password" autocomplete="off">
  <label for="replyKey">Reply API key (optional, reuses the Judge key when empty)</label><input id="replyKey" type="password" autocomplete="off">
  <label for="relationship">Who is the other person to you?</label><textarea id="relationship" rows="2"></textarea>
  <label><input id="auto" type="checkbox" style="width:auto"> Analyze automatically when they send a message</label>
  <details><summary>Advanced</summary>
    <label for="judgeUrl">Judge URL</label><input id="judgeUrl">
    <label for="judgeModel">Judge model</label><input id="judgeModel">
    <label for="replyUrl">Reply URL (…/chat/completions)</label><input id="replyUrl">
    <label for="replyModel">Reply model</label><input id="replyModel">
  </details>
  <p><button id="save">Save</button> <span id="status"></span></p>
  <script type="module" src="options.js"></script>
</body>
</html>
```

`extension/options.js`:

```js
const brain = await fetch("brain.json").then((r) => r.json());
const TEXT = ["judgeKey", "replyKey", "relationship", "judgeUrl", "judgeModel", "replyUrl", "replyModel"];
const PLACEHOLDER = {
  relationship: brain.default_relationship, judgeUrl: brain.judge_url_default,
  judgeModel: brain.judge_model_default, replyUrl: brain.reply_url_default, replyModel: brain.reply_model_default,
};
const $ = (id) => document.getElementById(id);

const saved = await chrome.storage.local.get([...TEXT, "auto"]);
for (const k of TEXT) { $(k).value = saved[k] ?? ""; $(k).placeholder = PLACEHOLDER[k] ?? ""; }
$("auto").checked = saved.auto ?? true;

$("save").onclick = async () => {
  const values = Object.fromEntries(TEXT.map((k) => [k, $(k).value.trim()]));
  // A custom API host needs its own permission; ask while we still have the click.
  const origins = [values.judgeUrl, values.replyUrl]
    .filter((u) => u && !u.startsWith("https://openrouter.ai/"))
    .map((u) => new URL(u).origin + "/*");
  if (origins.length && !(await chrome.permissions.request({ origins }))) {
    $("status").textContent = "Permission for the custom API host was denied; not saved.";
    return;
  }
  await chrome.storage.local.set({ ...values, auto: $("auto").checked });
  $("status").textContent = "Saved.";
};
```

- [ ] **Step 6: Unit tests and brain sync still pass**

Run: `cd extension && npm test && cd .. && python3 tools/sync_brain.py --check && python3 tools/check_cjk.py`
Expected: all green.

- [ ] **Step 7: Load it and run the acceptance checks (HUMAN + agent)**

In Chrome: `chrome://extensions` → Developer mode → **Load unpacked** → select `extension/`. Open the options (right-click the toolbar icon → Options), then paste an OpenRouter key and save. Click the toolbar icon to open the side panel.

Record the actual outcome of each row in `docs/acceptance.md` under "Chrome extension":

| # | Check | Pass when |
|---|---|---|
| 1 | Instagram web: test thread, other side sends "are you free tomorrow?" | Panel shows intent, risk and 3 ranked English replies within ~5 s |
| 2 | Fill on Instagram | Text appears in the message box; **nothing is sent**; typing afterwards still works (the editor didn't break) |
| 3 | Instagram inbox / feed | Panel doesn't analyze |
| 4 | Google Messages web: repeat 1–3 | Same outcomes |
| 5 | Wrong key | Panel shows "Something went wrong" + `HTTP 401: …`; no crash |
| 6 | DevTools console on both sites + service worker console | No message text logged |

- [ ] **Step 8: Docs and commit**

Add a "Laptop (Chrome)" section to `README.md` covering install (Load unpacked), key setup, the two supported sites, and "never sends". Add to the 1.4 entry in `CHANGELOG.md`: `- New: Chrome extension for Instagram web and Google Messages for web.`

```bash
git add extension README.md CHANGELOG.md docs/acceptance.md
git commit -m "feat(extension): side panel, analysis pipeline, fill, options"
```

## Out of scope (add when needed)

- Knowledge base / contact notes on the laptop. Android keeps them locally on the phone and there's no sync. Add when there's a sync story.
- Screenshot + OCR fallback in the browser. The DOM always has the text on these two sites.
- WhatsApp Web, Messenger, X web. Each is one more `sites/*.js` with the same `read`/`composer` contract.
- Chrome Web Store packaging.
