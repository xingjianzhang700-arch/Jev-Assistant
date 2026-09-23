# Jev for Mac (Apple Messages) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar app that reads the open conversation in Apple Messages (iMessage, plus SMS forwarded from an iPhone), shows Jev's read of the chat and 3 ranked replies in a floating panel, and fills the chosen reply into the Messages compose field. It never sends. This is how iPhone users get Jev: iOS doesn't let any app read another app's screen, so the Mac is where iMessage/SMS can be read.

**Architecture:** A Swift Package in `mac/` with three targets:
- **`JevCore`** (library, pure Foundation): the message models, the embedded shared brain (generated from `shared/jev-brain.json` by `tools/sync_brain.py`), the request builders and reply parsing (mirroring `extension/lib/core.js`), and `MessagesApp.parse(_: AXNode)`, which turns a plain tree of accessibility nodes into a snapshot.
- **`JevMac`** (executable, AppKit): reads Messages' accessibility tree into `AXNode`, polls while Messages is frontmost, calls the APIs, shows the panel, and fills through the Accessibility API. It stores keys in the Keychain, and `--dump` writes a tree to JSON for fixtures.
- **`JevChecks`** (executable): plain assertion checks against `JevCore` and JSON fixtures. Only Command Line Tools are installed here (no Xcode), so neither XCTest nor Swift Testing is available (verified 2026-09-22). `swift run JevChecks` is the test runner.

**Tech Stack:** Swift 6.3 toolchain in Swift 5 language mode (`swift-tools-version:5.10`), macOS 14+, AppKit, ApplicationServices (AX API), Security (Keychain), URLSession.

**Spec:** The user's request (2026-09-22): *"work on mobile and laptop"* → laptop = Chrome extension **and** a Mac app. This plan is the Mac app. The shared brain comes from `2026-09-22-laptop-chrome-extension.md` Task 1, which must be done first.

## Global Constraints

- **Never send.** Never post a Return key event, never press the send button, never use AppleScript `send`. Set the compose field's value and stop.
- **No reading Messages' database** (`~/Library/Messages/chat.db`). Accessibility API only. (This is upstream hard rule 1.)
- **Keys only in the Keychain** (service `com.jev.assistant.mac`). Never in UserDefaults, files or logs.
- **Don't log message content.** `print`/`NSLog` may carry counts and timings only.
- **Accessibility permission is granted by the user** in System Settings → Privacy & Security → Accessibility. The app may *prompt* through `AXIsProcessTrustedWithOptions`. Agents never change security settings.
- **Prompt text only from the embedded brain.** Never hand-edit `Brain.generated.swift`.
- Git: local commits on branch `english-instagram-sms`. Never push.

## File Structure

```
mac/
  Package.swift
  package.sh                         builds "build/Jev Assistant.app" (ad-hoc signed)
  Fixtures/messages_window.json      hand-written tree (open conversation)
  Fixtures/messages_no_convo.json    hand-written tree (no conversation open)
  Fixtures/messages_unreadable.json  hand-written tree (conversation, no readable text)
  Fixtures/*_real.json + README.md   real dumps (Task 3)
  Sources/JevCore/Brain.generated.swift   (tools/sync_brain.py)
  Sources/JevCore/Brain.swift        parse embedded JSON; brainString(); brainLabel()
  Sources/JevCore/Models.swift       Msg, Snapshot, RankedReply, Summary
  Sources/JevCore/Prompt.swift       request bodies, parseThree, ranked, summary
  Sources/JevCore/AXNode.swift       Codable plain node tree
  Sources/JevCore/MessagesApp.swift  parse(window) -> Snapshot?
  Sources/JevChecks/main.swift       assertion checks
  Sources/JevMac/main.swift          entry: --dump or run the app
  Sources/JevMac/AXReader.swift      AXUIElement -> AXNode; composer lookup; fill
  Sources/JevMac/Api.swift           POST JSON with retry
  Sources/JevMac/Keychain.swift
  Sources/JevMac/Settings.swift      UserDefaults (non-secret) with brain defaults
  Sources/JevMac/ReplyPanel.swift    floating panel UI
  Sources/JevMac/AppDelegate.swift   menu bar, polling, analysis, fill
```

---

### Task 1: Package, embedded brain, prompt logic

**Files:**
- Create: `mac/Package.swift`, `mac/Sources/JevCore/{Brain,Models,Prompt}.swift`, `mac/Sources/JevChecks/main.swift`, placeholder `mac/Sources/JevMac/main.swift`
- Generate: `mac/Sources/JevCore/Brain.generated.swift`
- Modify: `.gitignore` (add `mac/.build/` and `mac/build/`)

**Interfaces:**
- Consumes: `shared/jev-brain.json` (keys listed in the extension plan, Task 1).
- Produces (`JevCore`, all `public`):
  - `struct Msg: Equatable { side: String; text: String; init(_ side: String, _ text: String) }`
  - `struct Snapshot: Equatable { title: String?; messages: [Msg]; var latestFrom: String?; var signature: String }`
  - `struct RankedReply: Equatable { text: String; prob: Double }`
  - `struct Summary: Equatable { intent: String?; risk: Double?; needs: String?; bestAction: String?; specificsOk: Double?; tensionResolved: Double? }`
  - `let brain: [String: Any]`, `func brainString(_ key: String) -> String`, `func brainLabel(_ group: String, _ key: String) -> String`
  - `enum Prompt { state, judgeBody, rankBody, draftBody, parseThree, ranked, summary }` (signatures in Step 4)
  - `func sideByEdges(left: Double, right: Double, width: Double) -> String`

- [ ] **Step 1: Package manifest**

`mac/Package.swift`:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "JevMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JevCore"),
        .executableTarget(name: "JevMac", dependencies: ["JevCore"]),
        // No Xcode on the build machine means no XCTest / Swift Testing:
        // checks are a plain program. Run: swift run JevChecks
        .executableTarget(name: "JevChecks", dependencies: ["JevCore"]),
    ]
)
```

`mac/Sources/JevMac/main.swift` (placeholder until Task 3):

```swift
print("Jev for Mac: not wired yet")
```

```bash
mkdir -p mac/Sources/JevCore mac/Sources/JevChecks mac/Sources/JevMac mac/Fixtures
python3 tools/sync_brain.py
printf 'mac/.build/\nmac/build/\n' >> .gitignore
```

Expected: `wrote mac/Sources/JevCore/Brain.generated.swift`.

- [ ] **Step 2: Write the failing checks**

`mac/Sources/JevChecks/main.swift`:

```swift
import Foundation
import JevCore

var failures = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String, line: UInt = #line) {
    if ok() { print("ok   \(what)") } else { print("FAIL \(what) (main.swift:\(line))"); failures += 1 }
}

let convo = [Msg("other", "hi"), Msg("me", "hey!"), Msg("other", "free tonight?")]
let snap = Snapshot(title: "Sam", messages: convo)

// Prompt: state
let many = (0..<12).map { Msg($0 % 2 == 1 ? "me" : "other", "m\($0)") }
let st = Prompt.state(Snapshot(title: nil, messages: many), relationship: "friend")["chat"] as! [String: Any]
check((st["messages"] as! [[String: String]]).count == 10, "state keeps last 10")
check((st["messages"] as! [[String: String]])[0] == ["from": "other", "text": "m2"], "state starts at m2")
check(st["latest_from"] as? String == "me", "state latest_from")

// Prompt: bodies
let jb = Prompt.judgeBody(snap, relationship: "friend", model: "typesafe/jev-1.13")
check((jb["questions"] as? [String: Any])?.count == 7, "judge body has 7 questions")
let rb = Prompt.rankBody(snap, relationship: "friend", model: "m", candidates: ["a", "b", "c"])
let best = (rb["questions"] as! [String: Any])["best_reply"] as! [String: Any]
check(best["criteria"] as? [String: String] == ["reply_a": "a", "reply_b": "b", "reply_c": "c"], "rank criteria")
check(best["instructions"] as? String == brainString("rank_instructions"), "rank instructions from brain")
let db = Prompt.draftBody(snap, relationship: "friend", model: "m")
let dm = db["messages"] as! [[String: String]]
check(dm[0]["content"] == brainString("draft_system"), "draft system from brain")
check(dm[1]["content"] == "Relationship: friend\n\nRecent conversation:\nThem: hi\nMe: hey!\nThem: free tonight?\n\nGive 3 candidate replies.",
      "draft user template filled")

// Prompt: parsing
let fb = brainString("fallback_reply")
check(Prompt.parseThree("Sure:\n[\"a\", \" b \", \"c\", \"d\"]") == ["a", "b", "c"], "parseThree JSON")
check(Prompt.parseThree("1. yes\n2. no") == ["yes", "no", fb], "parseThree lines + pad")
check(Prompt.parseThree("") == [fb, fb, fb], "parseThree empty")
let rk = Prompt.ranked(["probabilities": ["reply_a": 0.2, "reply_b": 0.7, "reply_c": 0.1]], ["a", "b", "c"])
check(rk.map(\.text) == ["b", "a", "c"], "ranked sorts by prob")
let sm = Prompt.summary([
    "true_intent": ["choice": "casual_chat"], "danger_level": ["score": 1.4], "she_needs": ["choice": "nothing"],
    "best_action": ["choice": "make_plan"], "should_reply_now": ["noul": 0.9], "tension_resolved": ["noul": 0.95],
])
check(sm == Summary(intent: "casual_chat", risk: 1.4, needs: "nothing", bestAction: "make_plan",
                    specificsOk: 0.9, tensionResolved: 0.95), "summary fields")
check(brainLabel("intent", "casual_chat") == "casual chat", "labels from brain")

// Side rule
check(sideByEdges(left: 20, right: 270, width: 700) == "other", "short incoming")
check(sideByEdges(left: 450, right: 680, width: 700) == "me", "short outgoing")
check(sideByEdges(left: 20, right: 600, width: 700) == "other", "long incoming")

print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd mac && swift run JevChecks`
Expected: build FAILS, `cannot find 'Msg' in scope` (and similar).

- [ ] **Step 4: Implement `JevCore`**

`mac/Sources/JevCore/Brain.swift`:

```swift
import Foundation

/// shared/jev-brain.json, embedded by tools/sync_brain.py (Brain.generated.swift).
public let brain: [String: Any] = {
    guard let obj = try? JSONSerialization.jsonObject(with: Data(brainJSONText.utf8)) as? [String: Any] else {
        fatalError("Brain.generated.swift is not valid JSON; rerun tools/sync_brain.py")
    }
    return obj
}()

public func brainString(_ key: String) -> String { brain[key] as? String ?? "" }

/// Display label for a Jev answer key, e.g. ("intent", "casual_chat") -> "casual chat".
public func brainLabel(_ group: String, _ key: String) -> String {
    ((brain["labels"] as? [String: Any])?[group] as? [String: String])?[key] ?? key
}
```

`mac/Sources/JevCore/Models.swift`:

```swift
public struct Msg: Equatable {
    public let side: String   // "me" | "other"
    public let text: String
    public init(_ side: String, _ text: String) { self.side = side; self.text = text }
}

public struct Snapshot: Equatable {
    public let title: String?
    public let messages: [Msg]
    public init(title: String?, messages: [Msg]) { self.title = title; self.messages = messages }
    public var latestFrom: String? { messages.last?.side }
    public var signature: String {
        (title ?? "") + "#" + messages.suffix(6).map { "\($0.side):\($0.text)" }.joined(separator: "|")
    }
}

public struct RankedReply: Equatable {
    public let text: String
    public let prob: Double
}

public struct Summary: Equatable {
    public let intent: String?
    public let risk: Double?
    public let needs: String?
    public let bestAction: String?
    public let specificsOk: Double?
    public let tensionResolved: Double?
    public init(intent: String?, risk: Double?, needs: String?, bestAction: String?,
                specificsOk: Double?, tensionResolved: Double?) {
        self.intent = intent; self.risk = risk; self.needs = needs; self.bestAction = bestAction
        self.specificsOk = specificsOk; self.tensionResolved = tensionResolved
    }
}

/// "me" when the bubble hugs the right edge more than the left.
public func sideByEdges(left: Double, right: Double, width: Double) -> String {
    width - right < left ? "me" : "other"
}
```

`mac/Sources/JevCore/Prompt.swift`:

```swift
import Foundation

/// Request bodies and response parsing. Mirrors extension/lib/core.js; the
/// wording comes only from the embedded brain.
public enum Prompt {
    public static func state(_ s: Snapshot, relationship: String) -> [String: Any] {
        let last = Array(s.messages.suffix(10))
        return ["chat": [
            "relationship": relationship,
            "messages": last.map { ["from": $0.side, "text": $0.text] },
            "latest_from": last.last?.side ?? "other",
        ] as [String: Any]]
    }

    public static func judgeBody(_ s: Snapshot, relationship: String, model: String) -> [String: Any] {
        ["model": model, "state": state(s, relationship: relationship), "questions": brain["judge_questions"] ?? [:]]
    }

    public static func rankBody(_ s: Snapshot, relationship: String, model: String, candidates: [String]) -> [String: Any] {
        let criteria = ["reply_a": candidates[0], "reply_b": candidates[1], "reply_c": candidates[2]]
        return ["model": model, "state": state(s, relationship: relationship),
                "questions": ["best_reply": ["type": "choice",
                                             "instructions": brainString("rank_instructions"),
                                             "criteria": criteria] as [String: Any]]]
    }

    public static func draftBody(_ s: Snapshot, relationship: String, model: String) -> [String: Any] {
        let convo = s.messages.suffix(10).map { ($0.side == "me" ? "Me" : "Them") + ": " + $0.text }
            .joined(separator: "\n")
        let user = brainString("draft_user_template")
            .replacingOccurrences(of: "{relationship}", with: relationship)
            .replacingOccurrences(of: "{conversation}", with: convo)
        return ["model": model, "temperature": 0.8,
                "messages": [["role": "system", "content": brainString("draft_system")],
                             ["role": "user", "content": user]]]
    }

    /// Same rules as Android's ReplyClient.parseThree.
    public static func parseThree(_ content: String) -> [String] {
        var out: [String] = []
        if let a = content.firstIndex(of: "["), let b = content.lastIndex(of: "]"), a < b,
           let arr = try? JSONSerialization.jsonObject(with: Data(content[a...b].utf8)) as? [Any] {
            out = arr.map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        if out.isEmpty {
            out = content.split(separator: "\n")
                .map { String($0.trimmingCharacters(in: .whitespaces).drop(while: { "-*123. \"".contains($0) })) }
                .filter { !$0.isEmpty }
        }
        out = Array(out.prefix(3))
        while out.count < 3 { out.append(brainString("fallback_reply")) }
        return out
    }

    public static func ranked(_ bestReply: [String: Any]?, _ candidates: [String]) -> [RankedReply] {
        let keys = ["reply_a", "reply_b", "reply_c"]
        let p = bestReply?["probabilities"] as? [String: Any] ?? [:]
        return candidates.enumerated()
            .map { RankedReply(text: $0.element, prob: (p[keys[$0.offset]] as? NSNumber)?.doubleValue ?? 0) }
            .sorted { $0.prob > $1.prob }
    }

    public static func summary(_ a: [String: Any]) -> Summary {
        func obj(_ k: String) -> [String: Any]? { a[k] as? [String: Any] }
        func num(_ k: String, _ f: String) -> Double? { (obj(k)?[f] as? NSNumber)?.doubleValue }
        return Summary(intent: obj("true_intent")?["choice"] as? String, risk: num("danger_level", "score"),
                       needs: obj("she_needs")?["choice"] as? String, bestAction: obj("best_action")?["choice"] as? String,
                       specificsOk: num("should_reply_now", "noul"), tensionResolved: num("tension_resolved", "noul"))
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd mac && swift run JevChecks`
Expected: every line `ok`, then `ALL CHECKS PASSED`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add mac .gitignore
git commit -m "feat(mac): Swift package with embedded shared brain and checked prompt logic"
```

---

### Task 2: Accessibility tree model and the Messages parser

**Files:**
- Create: `mac/Sources/JevCore/AXNode.swift`, `mac/Sources/JevCore/MessagesApp.swift`
- Create: `mac/Fixtures/messages_window.json`, `messages_no_convo.json`, `messages_unreadable.json`
- Modify: `mac/Sources/JevChecks/main.swift` (add a parser section before the final `print`)

**Interfaces:**
- Produces:
  - `public struct AXNode: Codable, Equatable { role, subrole, identifier, value, title, desc: String; x, y, w, h: Double; editable: Bool; children: [AXNode]; init(); func flattened() -> [AXNode]; var text: String }`. Missing JSON keys decode to ""/0/false/[].
  - `public enum MessagesApp { static let bundleID = "com.apple.MobileSMS"; static func parse(_ window: AXNode) -> Snapshot?; static func isComposer(_ n: AXNode) -> Bool; static func isBody(_ n: AXNode) -> Bool }`
  - Contract: `nil` = no conversation open; `messages == []` = a conversation is open but no text is readable.

**Expected Messages layout** (confirmed or corrected by Task 3): a sidebar scroll area (conversation list, with a search field of subrole `AXSearchField`), a transcript scroll area whose bubbles are non-editable `AXTextArea`s carrying their text in `AXValue`, a header `AXStaticText` above the transcript with the contact's name, and an editable compose `AXTextArea`/`AXTextField`. The side comes from where a bubble sits within the transcript's width.

- [ ] **Step 1: Fixtures**

`mac/Fixtures/messages_window.json`:

```json
{"role": "AXWindow", "x": 0, "y": 0, "w": 1000, "h": 1000, "children": [
  {"role": "AXTextField", "subrole": "AXSearchField", "editable": true, "x": 10, "y": 50, "w": 280, "h": 24},
  {"role": "AXScrollArea", "x": 0, "y": 80, "w": 300, "h": 920, "children": [
    {"role": "AXStaticText", "value": "Sam", "x": 60, "y": 100, "w": 100, "h": 20},
    {"role": "AXStaticText", "value": "see you at 7", "x": 60, "y": 122, "w": 200, "h": 18}]},
  {"role": "AXStaticText", "value": "Sam", "x": 600, "y": 60, "w": 60, "h": 20},
  {"role": "AXScrollArea", "x": 300, "y": 100, "w": 700, "h": 780, "children": [
    {"role": "AXGroup", "x": 300, "y": 120, "w": 700, "h": 40, "children": [
      {"role": "AXTextArea", "value": "are we still on for 7?", "x": 320, "y": 120, "w": 250, "h": 36}]},
    {"role": "AXGroup", "x": 300, "y": 170, "w": 700, "h": 40, "children": [
      {"role": "AXTextArea", "value": "yes, see you there", "x": 750, "y": 170, "w": 230, "h": 36}]},
    {"role": "AXGroup", "x": 300, "y": 220, "w": 700, "h": 40, "children": [
      {"role": "AXTextArea", "value": "see you at 7", "x": 320, "y": 220, "w": 200, "h": 36}]}]},
  {"role": "AXTextArea", "editable": true, "x": 340, "y": 900, "w": 600, "h": 30}
]}
```

`mac/Fixtures/messages_no_convo.json`:

```json
{"role": "AXWindow", "x": 0, "y": 0, "w": 1000, "h": 1000, "children": [
  {"role": "AXTextField", "subrole": "AXSearchField", "editable": true, "x": 10, "y": 50, "w": 280, "h": 24},
  {"role": "AXScrollArea", "x": 0, "y": 80, "w": 300, "h": 920, "children": [
    {"role": "AXStaticText", "value": "Sam", "x": 60, "y": 100, "w": 100, "h": 20}]}
]}
```

`mac/Fixtures/messages_unreadable.json`:

```json
{"role": "AXWindow", "x": 0, "y": 0, "w": 1000, "h": 1000, "children": [
  {"role": "AXScrollArea", "x": 300, "y": 100, "w": 700, "h": 780, "children": [
    {"role": "AXImage", "x": 320, "y": 120, "w": 250, "h": 200}]},
  {"role": "AXTextArea", "editable": true, "x": 340, "y": 900, "w": 600, "h": 30}
]}
```

- [ ] **Step 2: Add the failing checks**

Insert into `mac/Sources/JevChecks/main.swift`, just before the final `print(failures == 0 ...)` line:

```swift
// Messages parser
let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../Fixtures").standardized
func load(_ name: String) -> AXNode {
    try! JSONDecoder().decode(AXNode.self, from: Data(contentsOf: fixtures.appendingPathComponent(name)))
}
let open = MessagesApp.parse(load("messages_window.json"))
check(open?.title == "Sam", "messages: title from header above transcript")
check(open?.messages == [Msg("other", "are we still on for 7?"), Msg("me", "yes, see you there"),
                         Msg("other", "see you at 7")], "messages: bodies in order with sides")
check(MessagesApp.parse(load("messages_no_convo.json")) == nil, "messages: no conversation -> nil")
let unreadable = MessagesApp.parse(load("messages_unreadable.json"))
check(unreadable != nil && unreadable!.messages.isEmpty, "messages: unreadable conversation -> empty")
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd mac && swift run JevChecks`
Expected: build FAILS, `cannot find 'AXNode' in scope`.

- [ ] **Step 4: Implement**

`mac/Sources/JevCore/AXNode.swift`:

```swift
/// A plain copy of one accessibility element, so the parser runs on JSON
/// fixtures as well as on a live tree (JevMac/AXReader builds these).
public struct AXNode: Codable, Equatable {
    public var role = "", subrole = "", identifier = "", value = "", title = "", desc = ""
    public var x = 0.0, y = 0.0, w = 0.0, h = 0.0
    public var editable = false
    public var children: [AXNode] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case role, subrole, identifier, value, title, desc, x, y, w, h, editable, children
    }

    /// Missing keys default, so hand-written fixtures stay short.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: k) ?? "" }
        func n(_ k: CodingKeys) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? 0 }
        role = try s(.role); subrole = try s(.subrole); identifier = try s(.identifier)
        value = try s(.value); title = try s(.title); desc = try s(.desc)
        x = try n(.x); y = try n(.y); w = try n(.w); h = try n(.h)
        editable = try c.decodeIfPresent(Bool.self, forKey: .editable) ?? false
        children = try c.decodeIfPresent([AXNode].self, forKey: .children) ?? []
    }

    /// Pre-order: self, then each child's subtree.
    public func flattened() -> [AXNode] { [self] + children.flatMap { $0.flattened() } }

    public var text: String { !value.isEmpty ? value : (!title.isEmpty ? title : desc) }
}
```

`mac/Sources/JevCore/MessagesApp.swift`:

```swift
import Foundation

/// Apple Messages (com.apple.MobileSMS). Layout confirmed against Fixtures/*_real.json.
public enum MessagesApp {
    public static let bundleID = "com.apple.MobileSMS"

    public static func isComposer(_ n: AXNode) -> Bool {
        n.editable && (n.role == "AXTextArea" || n.role == "AXTextField") && n.subrole != "AXSearchField"
    }

    public static func isBody(_ n: AXNode) -> Bool {
        n.role == "AXTextArea" && !n.editable && !n.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// nil = no conversation open; empty messages = open but unreadable.
    public static func parse(_ window: AXNode) -> Snapshot? {
        let all = window.flattened()
        guard all.contains(where: isComposer) else { return nil }
        // The transcript is the scroll area holding the most bubbles; on a tie
        // prefer the narrower one (an outer container also "holds" them).
        let areas = all.filter { $0.role == "AXScrollArea" }.map { ($0, $0.flattened().filter(isBody)) }
        guard let best = areas.max(by: { $0.1.count != $1.1.count ? $0.1.count < $1.1.count : $0.0.w > $1.0.w }),
              !best.1.isEmpty else { return Snapshot(title: nil, messages: []) }
        let area = best.0
        let msgs = best.1.sorted { $0.y < $1.y }.map { b in
            Msg(sideByEdges(left: b.x - area.x, right: b.x + b.w - area.x, width: area.w),
                b.value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Header name: the static text closest above the transcript, within its column.
        let title = all.filter {
            $0.role == "AXStaticText" && !$0.text.isEmpty && $0.text.count <= 40 &&
                $0.y + $0.h <= area.y + 1 && $0.x >= area.x - 1 && $0.x < area.x + area.w
        }.max { $0.y < $1.y }?.text
        return Snapshot(title: title, messages: msgs)
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd mac && swift run JevChecks`
Expected: `ALL CHECKS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add mac
git commit -m "feat(mac): AXNode model and Messages conversation parser with fixtures"
```

---

### Task 3: Live AX reader, `--dump`, and real fixtures (HUMAN + agent)

**Files:**
- Create: `mac/Sources/JevMac/AXReader.swift`
- Replace: `mac/Sources/JevMac/main.swift`
- Create: `mac/Fixtures/messages_window_real.json`, `messages_no_convo_real.json`, `mac/Fixtures/README.md`
- Modify: `mac/Sources/JevChecks/main.swift` (real-fixture checks)

**Interfaces:**
- Consumes: `AXNode`, `MessagesApp` (Task 2).
- Produces (`JevMac`, internal): `AXReader.messagesWindow() -> AXUIElement?`, `AXReader.tree(_:budget:) -> AXNode`, `AXReader.fill(_ text: String) -> Bool`; CLI `JevMac --dump <path>`.

- [ ] **Step 1: `mac/Sources/JevMac/AXReader.swift`**

```swift
import AppKit
import ApplicationServices
import JevCore

/// Reads Messages through the Accessibility API. Never presses keys or buttons.
enum AXReader {
    private static let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXIdentifierAttribute, kAXValueAttribute,
                                kAXTitleAttribute, kAXDescriptionAttribute, kAXPositionAttribute, kAXSizeAttribute,
                                kAXChildrenAttribute] as CFArray

    static func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    static func messagesWindow() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: MessagesApp.bundleID).first
        else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        guard let w = attr(ax, kAXFocusedWindowAttribute) ?? attr(ax, kAXMainWindowAttribute) else { return nil }
        return (w as! AXUIElement)
    }

    private static func isEditableText(_ e: AXUIElement, role: String) -> Bool {
        guard role == "AXTextArea" || role == "AXTextField" else { return false }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(e, kAXValueAttribute as CFString, &settable)
        return settable.boolValue
    }

    /// One IPC round trip per element (CopyMultipleAttributeValues), capped by `budget`.
    static func tree(_ e: AXUIElement, depth: Int = 0, budget: inout Int) -> AXNode {
        budget -= 1
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(e, names, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        let v = (values as? [AnyObject]) ?? []
        func str(_ i: Int) -> String { i < v.count ? (v[i] as? String ?? "") : "" }
        var n = AXNode()
        n.role = str(0); n.subrole = str(1); n.identifier = str(2)
        n.value = str(3); n.title = str(4); n.desc = str(5)
        var p = CGPoint.zero, s = CGSize.zero
        if v.count > 7, CFGetTypeID(v[6]) == AXValueGetTypeID() { AXValueGetValue(v[6] as! AXValue, .cgPoint, &p) }
        if v.count > 7, CFGetTypeID(v[7]) == AXValueGetTypeID() { AXValueGetValue(v[7] as! AXValue, .cgSize, &s) }
        n.x = p.x; n.y = p.y; n.w = s.width; n.h = s.height
        n.editable = isEditableText(e, role: n.role)
        if depth < 60, budget > 0, v.count > 8, let kids = v[8] as? [AXUIElement] {
            n.children = kids.map { tree($0, depth: depth + 1, budget: &budget) }
        }
        return n
    }

    /// The compose field (same rule as MessagesApp.isComposer), for writing into.
    static func composer(_ e: AXUIElement, depth: Int = 0) -> AXUIElement? {
        let role = attr(e, kAXRoleAttribute) as? String ?? ""
        let subrole = attr(e, kAXSubroleAttribute) as? String ?? ""
        if subrole != "AXSearchField" && isEditableText(e, role: role) { return e }
        guard depth < 60, let kids = attr(e, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for k in kids { if let hit = composer(k, depth: depth + 1) { return hit } }
        return nil
    }

    /// Put text in the compose field and read it back. Never sends.
    static func fill(_ text: String) -> Bool {
        guard let w = messagesWindow(), let box = composer(w),
              AXUIElementSetAttributeValue(box, kAXValueAttribute as CFString, text as CFString) == .success
        else { return false }
        return (attr(box, kAXValueAttribute) as? String) == text
    }
}
```

- [ ] **Step 2: `mac/Sources/JevMac/main.swift` with the dump mode**

```swift
import AppKit
import ApplicationServices
import JevCore

let args = CommandLine.arguments
if args.count >= 3, args[1] == "--dump" {
    guard AXIsProcessTrusted() else {
        print("Grant Accessibility access to the app running this command (System Settings → Privacy & Security → Accessibility), then retry.")
        exit(1)
    }
    guard let w = AXReader.messagesWindow() else { print("Open Messages with a conversation showing, then retry."); exit(1) }
    var budget = 8000
    let node = AXReader.tree(w, budget: &budget)
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try! enc.encode(node).write(to: URL(fileURLWithPath: args[2]))
    print("wrote \(args[2]) (\(8000 - budget) elements)")
    exit(0)
}

print("Jev for Mac: app not wired yet (Task 5). Use --dump <file>.")
```

Run: `cd mac && swift build`
Expected: `Build complete!`.

- [ ] **Step 3: Grant Accessibility to the terminal (HUMAN STEP)**

The owner adds the terminal app they're running commands from (Terminal, iTerm, or Claude's host app) under System Settings → Privacy & Security → Accessibility. Agents don't change security settings.

- [ ] **Step 4: Capture dumps (HUMAN + agent)**

Open Messages on a **test conversation** (iMessage or SMS) that has messages from both sides and ends with one from the other person. Then:

```bash
cd mac && swift run JevMac --dump Fixtures/messages_window_real.json
```

Then click a spot in the sidebar where no conversation is selected, or open a new empty message window, and run:

```bash
swift run JevMac --dump Fixtures/messages_no_convo_real.json
```

Expected: `wrote … (N elements)` with N in the hundreds. If N is under ~20, Messages isn't exposing its tree. Stop and report.

Before committing, open the JSON and replace any real names or numbers.

- [ ] **Step 5: Confirm the layout**

```bash
python3 - <<'EOF'
import json
def walk(n, d=0):
    t = n.get("value") or n.get("title") or n.get("desc") or ""
    if n.get("role") in ("AXScrollArea", "AXTextArea", "AXTextField", "AXStaticText") or n.get("editable"):
        print("  " * min(d, 12) + f'{n["role"]}/{n.get("subrole","")} ed={n.get("editable")} x={n["x"]:.0f} w={n["w"]:.0f} "{t[:40]}"')
    for c in n.get("children", []): walk(c, d + 1)
walk(json.load(open("Fixtures/messages_window_real.json", encoding="utf-8")))
EOF
```

Check the expected layout from Task 2. The likely differences are bubbles as `AXStaticText` instead of `AXTextArea`, or text in `desc` instead of `value`. If you see one, change `MessagesApp.isBody` (and the body text source in `parse`) to match the dump, update the hand-written fixtures the same way, and re-run `swift run JevChecks`.

- [ ] **Step 6: README and real-fixture checks**

`mac/Fixtures/README.md`: macOS version, Messages version, the confirmed roles, and for `messages_window_real.json` the title and the messages top to bottom with sides.

Add to `JevChecks/main.swift` (before the final `print`), with the literals from the README:

```swift
let real = MessagesApp.parse(load("messages_window_real.json"))
check(real?.title == "<title from README>", "real: title")
check(real?.messages == [Msg("other", "<first from README>"), Msg("me", "<second from README>")
                         /* ... every message in the README, in order */], "real: messages")
check(MessagesApp.parse(load("messages_no_convo_real.json")) == nil, "real: no conversation -> nil")
```

Run: `cd mac && swift run JevChecks`
Expected: `ALL CHECKS PASSED`. If a real check fails, fix the parser, not the check.

- [ ] **Step 7: Commit**

```bash
git add mac
git commit -m "feat(mac): live AX reader, --dump mode, real Messages fixtures"
```

---

### Task 4: API client, Keychain, settings

**Files:**
- Create: `mac/Sources/JevMac/Api.swift`, `Keychain.swift`, `Settings.swift`

**Interfaces:**
- Produces: `Api.post(_ url: String, key: String, body: [String: Any]) async throws -> [String: Any]`; `Keychain.get(_ account: String) -> String`, `Keychain.set(_ account: String, _ value: String)` (accounts `"judge"`, `"reply"`; an empty value deletes the key); `Settings.relationship` (get/set), `Settings.auto` (get/set), and read-only `Settings.judgeURL`, `judgeModel`, `replyURL`, `replyModel`.

This task is thin wrappers around system APIs. It's verified by building here and through real calls in Task 5's acceptance checks.

- [ ] **Step 1: `Api.swift`**

```swift
import Foundation

struct ApiError: LocalizedError {
    let errorDescription: String?
    init(_ m: String) { errorDescription = m }
}

/// POST JSON; retries 429/529 twice with backoff. Keys are never logged.
enum Api {
    static func post(_ url: String, key: String, body: [String: Any]) async throws -> [String: Any] {
        guard let u = URL(string: url) else { throw ApiError("Bad URL: \(url)") }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.timeoutInterval = 40
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if url.contains("openrouter.ai") {
            req.setValue("https://jev-assistant.local", forHTTPHeaderField: "HTTP-Referer")
            req.setValue("Jev Assistant", forHTTPHeaderField: "X-Title")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        for attempt in 0..<3 {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if (code == 429 || code == 529) && attempt < 2 {
                try await Task.sleep(nanoseconds: UInt64(1_000_000_000) << UInt64(attempt))
                continue
            }
            guard (200..<300).contains(code) else {
                throw ApiError("HTTP \(code): \(String(decoding: data.prefix(120), as: UTF8.self))")
            }
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        throw ApiError("Service busy, try again")
    }
}
```

- [ ] **Step 2: `Keychain.swift`**

```swift
import Foundation
import Security

/// API keys live only here (generic passwords, service com.jev.assistant.mac).
enum Keychain {
    private static let service = "com.jev.assistant.mac"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func get(_ account: String) -> String {
        var q = query(account)
        q[kSecReturnData as String] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    /// Empty value deletes the key.
    static func set(_ account: String, _ value: String) {
        SecItemDelete(query(account) as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query(account)
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
```

- [ ] **Step 3: `Settings.swift`**

```swift
import Foundation
import JevCore

/// Non-secret preferences. Endpoints and models default to the shared brain;
/// override with e.g. `defaults write com.jev.assistant.mac replyModel <id>`.
enum Settings {
    private static let d = UserDefaults.standard

    static var relationship: String {
        get { d.string(forKey: "relationship") ?? brainString("default_relationship") }
        set { d.set(newValue, forKey: "relationship") }
    }
    static var auto: Bool {
        get { d.object(forKey: "auto") as? Bool ?? true }
        set { d.set(newValue, forKey: "auto") }
    }
    static var judgeURL: String { d.string(forKey: "judgeURL") ?? brainString("judge_url_default") }
    static var judgeModel: String { d.string(forKey: "judgeModel") ?? brainString("judge_model_default") }
    static var replyURL: String { d.string(forKey: "replyURL") ?? brainString("reply_url_default") }
    static var replyModel: String { d.string(forKey: "replyModel") ?? brainString("reply_model_default") }
}
```

- [ ] **Step 4: Build and commit**

Run: `cd mac && swift build && swift run JevChecks`
Expected: `Build complete!` and `ALL CHECKS PASSED`.

```bash
git add mac
git commit -m "feat(mac): API client, Keychain storage, settings"
```

---

### Task 5: Menu-bar app, panel, polling, fill, packaging

**Files:**
- Create: `mac/Sources/JevMac/ReplyPanel.swift`, `mac/Sources/JevMac/AppDelegate.swift`, `mac/package.sh`
- Replace: the last line of `mac/Sources/JevMac/main.swift` (the "not wired yet" print)

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: `build/Jev Assistant.app`.

- [ ] **Step 1: `ReplyPanel.swift`**

```swift
import AppKit
import JevCore

/// Floating, non-activating panel: status, Jev's read, and 3 replies with Fill / Copy.
@MainActor
final class ReplyPanel {
    var onFill: ((String) -> Void)?
    private let panel: NSPanel
    private let stack = NSStackView()
    private var targets: [ClosureTarget] = []

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.title = "Jev"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        panel.contentView = stack
    }

    func show(title: String?) {
        panel.title = "Jev · \(title ?? "Messages")"
        bringUp()
    }

    func status(_ text: String) { set([label(text, secondary: true)]) }

    func error(_ text: String) { set([label("Something went wrong", bold: true), label(text, secondary: true)]) }

    func show(summary s: Summary, replies: [RankedReply]) {
        // Old buttons disappear in set(); buttons hold targets weakly, so we keep the live ones.
        targets.removeAll()
        var views: [NSView] = []
        if let i = s.intent { views.append(label("Their real intent: \(brainLabel("intent", i))", bold: true)) }
        var bits: [String] = []
        if let r = s.risk { bits.append("Risk \(Int(r.rounded()))/9") }
        if let n = s.needs { bits.append("Needs \(brainLabel("needs", n))") }
        if let a = s.bestAction { bits.append(brainLabel("action", a)) }
        if let ok = s.specificsOk { bits.append(ok >= 0.5 ? "OK to give specifics" : "Hold off on specifics") }
        if !bits.isEmpty { views.append(label(bits.joined(separator: " · "), secondary: true)) }
        if let t = s.tensionResolved, t >= 0.7 { views.append(label("✓ Tension resolved", secondary: true)) }
        views.append(label("Suggested replies (ranked by Jev)", secondary: true))
        views.append(contentsOf: replies.map(replyRow))
        set(views)
    }

    private func replyRow(_ r: RankedReply) -> NSView {
        let fill = button("Fill") { [weak self] in self?.onFill?(r.text) }
        let copy = button("Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(r.text, forType: .string)
        }
        let buttons = NSStackView(views: [fill, copy])
        let row = NSStackView(views: [label("\(Int((r.prob * 100).rounded()))%  \(r.text)"), buttons])
        row.orientation = .vertical
        row.alignment = .leading
        return row
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> NSButton {
        let t = ClosureTarget(action)
        targets.append(t)
        return NSButton(title: title, target: t, action: #selector(ClosureTarget.run))
    }

    private func label(_ s: String, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.preferredMaxLayoutWidth = 310
        if bold { l.font = .boldSystemFont(ofSize: 13) }
        if secondary { l.textColor = .secondaryLabelColor }
        return l
    }

    private func set(_ views: [NSView]) {
        stack.setViews(views, in: .top)
        bringUp()
    }

    private func bringUp() {
        guard !panel.isVisible else { return }
        if let f = NSScreen.main?.visibleFrame { panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - 360, y: f.maxY - 20)) }
        panel.orderFront(nil)
    }
}

/// NSButton target that runs a closure.
final class ClosureTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}
```

- [ ] **Step 2: `AppDelegate.swift`**

```swift
import AppKit
import ApplicationServices
import JevCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = ReplyPanel()
    private var timer: Timer?
    private var lastSig = ""
    private var current: Snapshot?
    private var busy = false

    func applicationDidFinishLaunching(_ note: Notification) {
        status.button?.title = "Jev"
        let menu = NSMenu()
        menu.addItem(item("Analyze now", #selector(analyzeNow)))
        let auto = item("Auto-analyze", #selector(toggleAuto(_:)))
        auto.state = Settings.auto ? .on : .off
        menu.addItem(auto)
        menu.addItem(.separator())
        menu.addItem(item("Set Judge API key…", #selector(setJudgeKey)))
        menu.addItem(item("Set Reply API key (optional)…", #selector(setReplyKey)))
        menu.addItem(item("Set relationship…", #selector(setRelationship)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Jev", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = menu

        // Shows the system prompt once; the user grants access in System Settings.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        panel.onFill = { [weak self] text in self?.fill(text) }
        // ponytail: polls every 1.5 s while Messages is frontmost. Switch to
        // AXObserver notifications if the tick shows up in Activity Monitor.
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func item(_ title: String, _ sel: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        i.target = self
        return i
    }

    private func tick() {
        guard AXIsProcessTrusted(),
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == MessagesApp.bundleID,
              let w = AXReader.messagesWindow() else { return }
        let t0 = Date()
        var budget = 8000
        let parsed = MessagesApp.parse(AXReader.tree(w, budget: &budget))
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        if ms > 300 { print("jev: slow tick \(ms) ms, \(8000 - budget) elements") }  // timing only, no content
        guard let snap = parsed else { return }
        current = snap
        guard snap.signature != lastSig else { return }
        lastSig = snap.signature
        panel.show(title: snap.title)
        if snap.messages.isEmpty { panel.status("Can't read this conversation's text."); return }
        if snap.latestFrom == "other" && Settings.auto { analyze(snap) }
        else { panel.status("Choose Analyze now in the Jev menu for suggestions.") }
    }

    @objc private func analyzeNow() {
        if let s = current, !s.messages.isEmpty { analyze(s) }
    }

    private func analyze(_ s: Snapshot) {
        guard !busy else { return }
        let judgeKey = Keychain.get("judge")
        guard !judgeKey.isEmpty else {
            panel.error("No Judge API key set. Choose Set Judge API key… in the Jev menu.")
            return
        }
        let stored = Keychain.get("reply")
        let replyKey = stored.isEmpty ? judgeKey : stored
        let rel = Settings.relationship
        busy = true
        panel.status("Analyzing…")
        Task {
            do {
                async let judged = Api.post(Settings.judgeURL, key: judgeKey,
                                            body: Prompt.judgeBody(s, relationship: rel, model: Settings.judgeModel))
                async let drafted = Api.post(Settings.replyURL, key: replyKey,
                                             body: Prompt.draftBody(s, relationship: rel, model: Settings.replyModel))
                let answers = (try await judged)["answers"] as? [String: Any] ?? [:]
                let choices = (try await drafted)["choices"] as? [[String: Any]]
                let content = (choices?.first?["message"] as? [String: Any])?["content"] as? String ?? ""
                let candidates = Prompt.parseThree(content)
                let rankResp = try await Api.post(Settings.judgeURL, key: judgeKey,
                    body: Prompt.rankBody(s, relationship: rel, model: Settings.judgeModel, candidates: candidates))
                let best = (rankResp["answers"] as? [String: Any])?["best_reply"] as? [String: Any]
                panel.show(summary: Prompt.summary(answers), replies: Prompt.ranked(best, candidates))
            } catch {
                panel.error(error.localizedDescription)
            }
            busy = false
        }
    }

    /// Write into the compose field; never sends. Falls back to the clipboard.
    private func fill(_ text: String) {
        if AXReader.fill(text) {
            panel.status("Filled in. Review it, then send it yourself.")
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            panel.status("Copied. Click the message box and press ⌘V.")
        }
    }

    private func ask(_ title: String, _ current: String, secure: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        let field = secure ? NSSecureTextField(frame: frame) : NSTextField(frame: frame)
        field.stringValue = current
        alert.accessoryView = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func setJudgeKey() { if let v = ask("Judge API key (OpenRouter). Empty clears it.", "", secure: true) { Keychain.set("judge", v) } }
    @objc private func setReplyKey() { if let v = ask("Reply API key. Empty reuses the Judge key.", "", secure: true) { Keychain.set("reply", v) } }
    @objc private func setRelationship() {
        if let v = ask("Who is the other person to you?", Settings.relationship, secure: false), !v.isEmpty { Settings.relationship = v }
    }
    @objc private func toggleAuto(_ sender: NSMenuItem) {
        Settings.auto.toggle()
        sender.state = Settings.auto ? .on : .off
    }
}
```

In `main.swift`, replace the last line (`print("Jev for Mac: app not wired yet …")`) with:

```swift
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
```

- [ ] **Step 3: `mac/package.sh`**

```bash
#!/bin/bash
# Build "build/Jev Assistant.app": a menu-bar app, ad-hoc signed.
# Ad-hoc signatures change every build, so macOS may ask for Accessibility again after a rebuild.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --product JevMac
APP="build/Jev Assistant.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/JevMac "$APP/Contents/MacOS/JevMac"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.jev.assistant.mac</string>
  <key>CFBundleName</key><string>Jev Assistant</string>
  <key>CFBundleExecutable</key><string>JevMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.4</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "built $APP"
```

```bash
chmod +x mac/package.sh && mac/package.sh
```

Expected: `built build/Jev Assistant.app`.

- [ ] **Step 4: Checks still pass**

Run: `cd mac && swift run JevChecks && cd .. && python3 tools/sync_brain.py --check && python3 tools/check_cjk.py`
Expected: all green.

- [ ] **Step 5: Acceptance (HUMAN + agent)**

`open "mac/build/Jev Assistant.app"`. Grant Accessibility when prompted (the owner does this in System Settings). Use the Jev menu to set the Judge API key. Record the actual outcome of each row in `docs/acceptance.md` under "Mac app":

| # | Check | Pass when |
|---|---|---|
| 1 | Messages frontmost, test conversation, the other side sends "are you free tomorrow?" | Panel shows intent, risk and 3 ranked replies within ~5 s |
| 2 | Fill | Text appears in the compose field; **nothing is sent** |
| 3 | Fill when the field can't be set (e.g. Messages minimized) | Panel says "Copied. Click the message box and press ⌘V."; the clipboard holds the reply |
| 4 | Switch to another app | Polling stops (no new panel updates) |
| 5 | Console.app filtered on "jev" | Only timing lines; no message text |
| 6 | Slow-tick lines | None, or under 300 ms typical. If ticks are often slow, record it: the upgrade is AXObserver (see the `ponytail:` note) |
| 7 | Quit from the menu, relaunch | Keys persist (Keychain); relationship persists |

- [ ] **Step 6: Docs and commit**

Add a "Mac (Apple Messages)" section to `README.md`: requirements (macOS 14+, Messages signed in, iPhone SMS forwarding on for SMS), build (`mac/package.sh`), permissions, "never sends". Add to the 1.4 entry in `CHANGELOG.md`: `- New: Mac menu-bar app for Apple Messages (iMessage and forwarded SMS).`

```bash
git add mac README.md CHANGELOG.md docs/acceptance.md
git commit -m "feat(mac): menu-bar app with reply panel, Messages polling and fill"
```

## Out of scope (add when needed)

- Notarized distribution / a Developer ID signature, which would keep the Accessibility grant stable across builds.
- AXObserver notifications instead of polling. Add when row 6 shows a real cost.
- Knowledge base on the Mac. There's no sync with the phone.
- Other Mac chat apps (WhatsApp desktop, Slack). Each needs its own dump and parser.
