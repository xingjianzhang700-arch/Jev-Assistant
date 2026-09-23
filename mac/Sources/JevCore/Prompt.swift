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
        let mood = obj("mood")
        let moodChoice = mood?["choice"] as? String
        let moodProbs = mood?["probabilities"] as? [String: Any]
        let moodRaw = moodChoice.flatMap { moodProbs?[$0] as? NSNumber } ?? mood?["confidence"] as? NSNumber
        return Summary(intent: obj("true_intent")?["choice"] as? String, risk: num("danger_level", "score"),
                       needs: obj("she_needs")?["choice"] as? String, bestAction: obj("best_action")?["choice"] as? String,
                       specificsOk: num("should_reply_now", "noul"), tensionResolved: num("tension_resolved", "noul"),
                       mood: moodChoice, moodPct: moodRaw.map { Int(($0.doubleValue * 100).rounded()) })
    }
}
