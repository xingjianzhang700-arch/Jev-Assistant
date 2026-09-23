# Finish Mac app and options URL validation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the work Claude Code left on branch `english-instagram-sms`: options save must reject a bad API URL without saving, and the Mac menu-bar app from the existing Mac plan must land in this same checkout.

**Architecture:** Stay in `/Users/andy/Jev Chat/jev-chat-jarvis` on `english-instagram-sms`. Do not open a second clone or worktree. The options fix is a pure function plus a save-path guard. The Mac app is the Swift package already specified in `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md`; this plan does not rewrite that source. It sequences those five tasks and records the amendments that later rulings made.

**Tech Stack:** Chrome MV3 options page (vanilla ES modules, Node `node --test`). Swift 5.10 package under `mac/` (`swift run JevChecks`).

**Spec:** User request 2026-09-22: finish the rest with subagents, in the same repo Claude was using. Parent plans: `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` (Mac tasks, full source) and `docs/superpowers/plans/2026-09-22-laptop-chrome-extension.md` Task 6 (options page). Ledger rulings R1, R12, R13, R15 in `.superpowers/sdd/`.

## Global Constraints

- Work only in this checkout, branch `english-instagram-sms`. Local commits. Do not push. Do not fork.
- Never send a message. Never post Return, never press Send, never AppleScript `send`.
- No reading `~/Library/Messages/chat.db`. Accessibility API only.
- Keys only in the Keychain (service `com.jev.assistant.mac`) on Mac, and `chrome.storage.local` for the extension. Never in UserDefaults, files, or logs.
- Do not log message content.
- Agents do not change Accessibility / security settings and do not capture the owner's real DMs into fixtures.
- Prompt text comes only from the shared brain. Do not hand-edit `Brain.generated.swift`.
- Selectors and Messages ids that were not captured on a device are described as expected, not verified. Point at the fixture README.
- `parseThree` line-splits only when no bracketed JSON array parsed. An empty array `[]` is a successful parse and must not fall through to line-splitting. Pad to 3 with the fallback after that.

## Review Focus

- A custom Judge URL of `not a url` must leave storage unchanged and show `Invalid URL: Judge URL`.
- A custom Reply URL of `not a url` must show `Invalid URL: Reply URL` and save nothing, even when the Judge URL is valid.
- `https://openrouter.ai/...` must not be sent to `chrome.permissions.request`.
- `Prompt.parseThree("Sure: []")` must return three fallback replies, not a line-split of `Sure:`.
- `MessagesApp` comments must say ids are expected and not yet verified on a device.

---

### Task 1: Reject invalid options URLs

**Files:**
- Create: `extension/lib/origins.js`
- Create: `extension/test/origins.test.js`
- Modify: `extension/options.js`

**Interfaces:**
- Consumes: `extension/options.js` save handler (already committed in `fea5ca9`).
- Produces: `export function customOrigins(judgeUrl, replyUrl) -> { origins: string[] } | { error: string }`.

- [ ] **Step 1: Write the failing test**

`extension/test/origins.test.js`:

```js
import assert from "node:assert/strict";
import { test } from "node:test";
import { customOrigins } from "../lib/origins.js";

test("blank and OpenRouter URLs need no extra permission", () => {
  assert.deepEqual(customOrigins("", "  "), { origins: [] });
  assert.deepEqual(
    customOrigins("https://openrouter.ai/api/v1/chat/completions", "https://openrouter.ai/api/v1"),
    { origins: [] },
  );
});

test("a custom https host becomes an origin pattern", () => {
  assert.deepEqual(customOrigins("https://api.example.com/v1", ""), {
    origins: ["https://api.example.com/*"],
  });
});

test("an unparseable Judge URL is named and blocks save", () => {
  assert.deepEqual(customOrigins("not a url", "https://api.example.com/v1"), {
    error: "Invalid URL: Judge URL",
  });
});

test("an unparseable Reply URL is named", () => {
  assert.deepEqual(customOrigins("https://api.example.com/v1", "::::"), {
    error: "Invalid URL: Reply URL",
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd extension && node --test test/origins.test.js`
Expected: FAIL, cannot find module `../lib/origins.js`.

- [ ] **Step 3: Implement**

`extension/lib/origins.js`:

```js
export function customOrigins(judgeUrl, replyUrl) {
  const origins = [];
  for (const [field, raw] of [["Judge URL", judgeUrl], ["Reply URL", replyUrl]]) {
    const u = String(raw ?? "").trim();
    if (!u || u.startsWith("https://openrouter.ai/")) continue;
    let parsed;
    try { parsed = new URL(u); } catch { return { error: `Invalid URL: ${field}` }; }
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return { error: `Invalid URL: ${field}` };
    }
    origins.push(`${parsed.origin}/*`);
  }
  return { origins };
}
```

In `extension/options.js`, add `import { customOrigins } from "./lib/origins.js";` and replace the `origins` computation inside the save handler with:

```js
  const gate = customOrigins(values.judgeUrl, values.replyUrl);
  if (gate.error) {
    $("status").textContent = gate.error;
    return;
  }
  if (gate.origins.length && !(await chrome.permissions.request({ origins: gate.origins }))) {
    $("status").textContent = "Permission for the custom API host was denied; not saved.";
    return;
  }
```

The function must not throw.

- [ ] **Step 4: Run tests**

Run: `cd extension && npm test && cd .. && python3 tools/sync_brain.py --check && python3 tools/check_cjk.py`
Expected: all green, `0 line(s) with Chinese text`.

- [ ] **Step 5: Commit**

```bash
git add extension/lib/origins.js extension/test/origins.test.js extension/options.js
git commit -m "fix(extension): reject invalid options URLs without saving"
```

---

### Task 2: Mac package, brain, prompt logic

**Files:** exactly the files in `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` Task 1.

**Interfaces:** that task's Produces block.

Implement that task's steps and source verbatim, with one amendment to `Prompt.parseThree`: track whether a bracketed JSON array parsed. Line-split only when it did not. Do not line-split when the array is empty.

```swift
    public static func parseThree(_ content: String) -> [String] {
        var out: [String] = []
        var parsed = false
        if let a = content.firstIndex(of: "["), let b = content.lastIndex(of: "]"), a < b,
           let arr = try? JSONSerialization.jsonObject(with: Data(content[a...b].utf8)) as? [Any] {
            out = arr.map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
            parsed = true
        }
        if !parsed {
            out = content.split(separator: "\n")
                .map { String($0.trimmingCharacters(in: .whitespaces).drop(while: { "-*123. \"".contains($0) })) }
                .filter { !$0.isEmpty }
        }
        out = Array(out.prefix(3))
        while out.count < 3 { out.append(brainString("fallback_reply")) }
        return out
    }
```

Add this check next to the other `parseThree` checks in `mac/Sources/JevChecks/main.swift` (the Mac plan's checks are the rest of the file):

```swift
check(Prompt.parseThree("Sure: []") == [String](repeating: brainString("fallback_reply"), count: 3), "empty array does not line-split")
```

Run: `cd mac && swift run JevChecks`
Expected: `ALL CHECKS PASSED`.

Commit message from the Mac plan Task 1: `feat(mac): Swift package with embedded shared brain and checked prompt logic`

---

### Task 3: AXNode and the Messages parser

Implement `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` Task 2 verbatim.

Amendment: `MessagesApp` comments say the fixture ids are expected values, not yet verified on a device, and point at `mac/Fixtures/README.md`. Do not write "verified against the dumps".

Commit message from that task: `feat(mac): AXNode model and Messages conversation parser with fixtures`

---

### Task 4: Live AX reader without real captures

Implement `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` Task 3's `AXReader.swift` and `--dump` CLI verbatim.

Do not run Messages. Do not write `messages_window_real.json` or `messages_no_convo_real.json`. Do not add JevChecks cases that load those files.

Create `mac/Fixtures/README.md` describing the hand-written fixtures, the expected roles, and the owner's capture steps from that task, marked real dumps pending. In `docs/acceptance.md`, record the Mac live rows this task would have run as `NOT RUN — needs owner`.

Commit message: `feat(mac): live AX reader and --dump mode`

---

### Task 5: API client, Keychain, settings

Implement `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` Task 4 verbatim, including its build command and commit message `feat(mac): API client, Keychain storage, settings`.

---

### Task 6: Menu-bar app, panel, packaging

Implement `docs/superpowers/plans/2026-09-22-laptop-mac-messages.md` Task 5 verbatim, including `package.sh` and the commit `feat(mac): menu-bar panel that reads Messages and fills a reply`.

The acceptance table in that task is a human step. Do not grant Accessibility. Record those rows in `docs/acceptance.md` as `NOT RUN — needs owner`. Build with `bash mac/package.sh` if the script's only requirement is the Swift toolchain already used by `swift build`. If code signing or a missing Xcode tool stops the script, commit the source and the script anyway and say which command failed.

---

## Self-review

- Spec coverage: invalid-URL save is Task 1. Mac package, parser, reader, API, and panel are Tasks 2–6, sourced from the Mac plan. Real device captures stay owner steps.
- Placeholders: Mac source stays in the parent plan so this file cannot drift from it. Amendments (empty-array parse, unverified wording, no real dumps) are written here in full.
- `customOrigins` return shape is `{ origins }` or `{ error }` in the test, the function, and the save handler.
