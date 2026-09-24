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
check((jb["questions"] as? [String: Any])?.count == 8, "judge body has 8 questions")
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
check(Prompt.parseThree("Sure: []") == [String](repeating: brainString("fallback_reply"), count: 3), "empty array does not line-split")
let rk = Prompt.ranked(["probabilities": ["reply_a": 0.2, "reply_b": 0.7, "reply_c": 0.1]], ["a", "b", "c"])
check(rk.map(\.text) == ["b", "a", "c"], "ranked sorts by prob")
let sm = Prompt.summary([
    "true_intent": ["choice": "casual_chat"], "danger_level": ["score": 1.4], "she_needs": ["choice": "nothing"],
    "best_action": ["choice": "make_plan"], "should_reply_now": ["noul": 0.9], "tension_resolved": ["noul": 0.95],
    "mood": ["choice": "angry", "confidence": 0.7,
             "probabilities": ["frustrated": 0.1, "furious": 0.2, "angry": 0.7, "warm": 0.05]],
])
check(sm == Summary(intent: "casual_chat", risk: 1.4, needs: "nothing", bestAction: "make_plan",
                    specificsOk: 0.9, tensionResolved: 0.95, mood: "angry", moodPct: 70,
                    moods: [MoodGuess("angry", 70), MoodGuess("furious", 20), MoodGuess("frustrated", 10)]),
      "summary fields")
check(Prompt.topMoods(["choice": "warm", "confidence": 0.5, "probabilities": ["warm": 0.81]]) ==
        [MoodGuess("warm", 81)], "top moods does not invent extras")
check(brainLabel("intent", "casual_chat") == "casual chat", "labels from brain")
check(brainLabel("mood", "frustrated") == "Frustrated", "mood labels title case")

// Side rule
check(sideByEdges(left: 20, right: 270, width: 700) == "other", "short incoming")
check(sideByEdges(left: 450, right: 680, width: 700) == "me", "short outgoing")
check(sideByEdges(left: 20, right: 600, width: 700) == "other", "long incoming")
// Trailing-edge rule: share the column's max right → me (gutter to window edge is irrelevant).
let cloud = sidesByBalloonEdges(lefts: [48, 288, 268], rights: [228, 428, 448])
check(cloud == ["other", "me", "me"], "sides from shared trailing edge, not window width")
check(sidesByBalloonEdges(lefts: [48], rights: [228]) == ["other"], "single balloon stays other")
let longMe = sidesByBalloonEdges(lefts: [1008, 1320, 1373], rights: [1398, 1398, 1398])
check(longMe == ["me", "me", "me"], "long outgoing stays me via trailing edge")
let mixed = sidesByBalloonEdges(lefts: [756, 1044, 1373], rights: [976, 1398, 1398])
check(mixed == ["other", "me", "me"], "left gray other, right blues me")

let sms = Snapshot(title: "Sam", messages: [Msg("other", "hi")])
check(macChatReads("com.apple.MobileSMS") && macChatReads("net.whatsapp.WhatsApp"), "Mac chat apps")
check(!macChatReads("org.mozilla.firefox") && !macChatReads("com.google.Chrome"), "browsers are not Mac chat")
check(keepChat(sms, frontmost: "org.mozilla.firefox") == nil, "leaving for Firefox drops SMS")
check(keepChat(sms, frontmost: "com.apple.MobileSMS")?.title == "Sam", "Messages keeps SMS")

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
let tahoe = MessagesApp.parse(load("messages_tahoe.json"))
check(tahoe?.title == "Sam", "tahoe: title from ConversationTitle")
check(tahoe?.messages == [Msg("other", "are we still on for 7?"), Msg("me", "yes, see you there"),
                          Msg("other", "see you at 7")], "tahoe: editable CKBalloonTextView bubbles")
// Wide window + gutter: outgoing share a trailing edge far from the window's right.
// Centered emoji is kept as a message but must not flip text sides.
let wide = MessagesApp.parse(load("messages_wide_window.json"))
check(wide?.title == "Pat", "wide: ConversationTitle")
check(wide?.messages == [Msg("other", "proofs again?"), Msg("me", "yeah toast"),
                         Msg("me", "😂"), Msg("me", "try the demo track"),
                         Msg("me", "I am drilling basics")],
      "wide: trailing-edge me/other; centered emoji inherits me")
let rowWidth = MessagesApp.parse(load("messages_row_width.json"))
check(rowWidth?.messages == [Msg("other", "you can retake that"),
                             Msg("me", "I am teaching myself the intro course")],
      "row-width text view uses the sticker on the right as me")

let wa = WhatsAppApp.parse(load("whatsapp_window.json"))
check(wa?.title == "Alex", "whatsapp: title above first message")
check(wa?.messages == [Msg("other", "are we still on for tonight?"), Msg("me", "yes! 7pm?"),
                       Msg("other", "perfect, see you there")], "whatsapp: in/out sides")
check(WhatsAppApp.parse(load("whatsapp_no_convo.json")) == nil, "whatsapp: no conversation -> nil")

// Screen OCR grouping (fake boxes only — no capture, no real DMs)
check(looksLikeScreenChrome("9:41 AM") && looksLikeScreenChrome("Delivered")
        && looksLikeScreenChrome("https://web.whatsapp.com"), "screen chrome clocks/receipts/urls")
check(!looksLikeScreenChrome("see you at 7"), "screen chrome keeps real lines")
let screenBoxes = [
    ScreenTextBox(text: "hey there", x: 40, y: 100, w: 120, h: 20),
    ScreenTextBox(text: "9:41 AM", x: 160, y: 40, w: 50, h: 12),
    ScreenTextBox(text: "hi!", x: 280, y: 140, w: 40, h: 20),
    ScreenTextBox(text: "Delivered", x: 280, y: 162, w: 55, h: 10),
    ScreenTextBox(text: "free later?", x: 40, y: 180, w: 100, h: 20),
]
let screenSnap = snapshotFromScreenText(screenBoxes)
check(screenSnap.messages == [Msg("other", "hey there"), Msg("me", "hi!"), Msg("other", "free later?")],
      "screen: lines → bubbles with trailing-edge sides")
// Centered emoji must not redefine the outgoing column.
let emojiBoxes = [
    ScreenTextBox(text: "proofs again?", x: 48, y: 100, w: 180, h: 20),
    ScreenTextBox(text: "yeah toast", x: 288, y: 140, w: 140, h: 20),
    ScreenTextBox(text: "😂", x: 200, y: 175, w: 28, h: 28),
    ScreenTextBox(text: "try the demo", x: 268, y: 220, w: 160, h: 20),
]
check(snapshotFromScreenText(emojiBoxes).messages == [
    Msg("other", "proofs again?"), Msg("me", "yeah toast"),
    Msg("me", "😂"), Msg("me", "try the demo"),
], "screen: centered emoji inherits side, does not flip")
// Instagram: inbox and the message box sit outside the open thread. Right bubble is you.
let ig = [
    ScreenTextBox(text: "Aisha", x: 40, y: 80, w: 80, h: 16),
    ScreenTextBox(text: "Active 10h ago", x: 40, y: 100, w: 90, h: 12),
    ScreenTextBox(text: "lol my twitter account is fried", x: 40, y: 200, w: 180, h: 16),
    ScreenTextBox(text: "When the scores came out he got stricter", x: 420, y: 180, w: 280, h: 36),
    ScreenTextBox(text: "lol", x: 860, y: 320, w: 36, h: 20),
    ScreenTextBox(text: "Message...", x: 400, y: 400, w: 200, h: 24),
]
check(snapshotFromScreenText(ig).messages == [
    Msg("other", "When the scores came out he got stricter"),
    Msg("me", "lol"),
], "screen: instagram inbox is ignored; right side is me")

print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
