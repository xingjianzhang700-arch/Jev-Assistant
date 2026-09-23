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
    "mood": ["choice": "playful", "confidence": 0.2, "probabilities": ["playful": 0.64, "annoyed": 0.1]],
])
check(sm == Summary(intent: "casual_chat", risk: 1.4, needs: "nothing", bestAction: "make_plan",
                    specificsOk: 0.9, tensionResolved: 0.95, mood: "playful", moodPct: 64), "summary fields")
check(brainLabel("intent", "casual_chat") == "casual chat", "labels from brain")

// Side rule
check(sideByEdges(left: 20, right: 270, width: 700) == "other", "short incoming")
check(sideByEdges(left: 450, right: 680, width: 700) == "me", "short outgoing")
check(sideByEdges(left: 20, right: 600, width: 700) == "other", "long incoming")

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

let wa = WhatsAppApp.parse(load("whatsapp_window.json"))
check(wa?.title == "Alex", "whatsapp: title above first message")
check(wa?.messages == [Msg("other", "are we still on for tonight?"), Msg("me", "yes! 7pm?"),
                       Msg("other", "perfect, see you there")], "whatsapp: in/out sides")
check(WhatsAppApp.parse(load("whatsapp_no_convo.json")) == nil, "whatsapp: no conversation -> nil")

print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED")
exit(failures == 0 ? 0 : 1)
