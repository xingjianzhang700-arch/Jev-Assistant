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
    public init(text: String, prob: Double) { self.text = text; self.prob = prob }
}

public struct MoodGuess: Equatable {
    public let key: String
    public let pct: Int?
    public init(_ key: String, _ pct: Int?) { self.key = key; self.pct = pct }
}

public struct Summary: Equatable {
    public let intent: String?
    public let risk: Double?
    public let needs: String?
    public let bestAction: String?
    public let specificsOk: Double?
    public let tensionResolved: Double?
    public let mood: String?
    public let moodPct: Int?
    public let moods: [MoodGuess]
    public init(intent: String?, risk: Double?, needs: String?, bestAction: String?,
                specificsOk: Double?, tensionResolved: Double?, mood: String? = nil, moodPct: Int? = nil,
                moods: [MoodGuess] = []) {
        self.intent = intent; self.risk = risk; self.needs = needs; self.bestAction = bestAction
        self.specificsOk = specificsOk; self.tensionResolved = tensionResolved
        self.mood = mood; self.moodPct = moodPct; self.moods = moods
    }
}

/// "me" when the bubble hugs the right edge more than the left of `width`.
/// Prefer `sidesByBalloonEdges` for Messages: the transcript AX frame is often
/// as wide as the window, while outgoing balloons only hug the balloon column.
public func sideByEdges(left: Double, right: Double, width: Double) -> String {
    width - right < left ? "me" : "other"
}

/// Right side of the chat is you. Left side is the other person.
///
/// A bubble is yours when it hugs the shared right edge (a long outgoing line
/// still ends on that edge) or its center sits in the right half of the column.
/// Slack is a few points, not a fraction of the window, so a long incoming
/// bubble that reaches toward the middle stays theirs.
public func sidesByBalloonEdges(lefts: [Double], rights: [Double]) -> [String] {
    precondition(lefts.count == rights.count)
    guard let maxR = rights.max(), let minL = lefts.min() else { return [] }
    if lefts.count == 1 { return ["other"] }
    let mid = (minL + maxR) / 2
    return zip(lefts, rights).map { left, right in
        if maxR - right <= 24 { return "me" }
        let center = (left + right) / 2
        return center >= mid && left >= mid * 0.5 + minL * 0.5 ? "me" : "other"
    }
}

/// Auto-follow / Accessibility path: Messages and WhatsApp Desktop only.
/// Browsers use Analyze now → screen capture (see ScreenChat / ScreenCapture).
public func macChatReads(_ bundle: String?) -> Bool {
    guard let bundle else { return false }
    return bundle == MessagesApp.bundleID || WhatsAppApp.bundleIDs.contains(bundle)
}

/// Drop the Accessibility-stored thread once the user leaves Messages / WhatsApp Desktop.
public func keepChat(_ snap: Snapshot?, frontmost: String?) -> Snapshot? {
    macChatReads(frontmost) ? snap : nil
}
