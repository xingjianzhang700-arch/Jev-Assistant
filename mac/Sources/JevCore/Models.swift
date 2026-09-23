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

/// Label each balloon from the shared trailing edge of the outgoing column.
///
/// Live Messages AX uses screen coordinates. Outgoing (blue) balloons share nearly
/// the same right edge even when a gutter sits between that column and the window's
/// right edge. Incoming (gray) balloons sit further left and do not share that edge.
/// Window / transcript width is never used — a centered emoji must not move `maxR`
/// unless it actually extends past the text column.
public func sidesByBalloonEdges(lefts: [Double], rights: [Double]) -> [String] {
    precondition(lefts.count == rights.count)
    guard let maxR = rights.max(), let minL = lefts.min() else { return [] }
    // One balloon alone has no trailing cluster to compare — treat as incoming
    // so Analyze drafts a reply to them rather than to yourself.
    if lefts.count == 1 { return ["other"] }
    let span = max(maxR - minL, 1)
    // ~one short bubble of slack; scales up on very wide clouds.
    let tol = max(28.0, span * 0.1)
    return rights.map { maxR - $0 <= tol ? "me" : "other" }
}

/// Menu-bar Jev only reads these apps. Instagram / Snapchat are the Chrome extension.
public func macChatReads(_ bundle: String?) -> Bool {
    guard let bundle else { return false }
    return bundle == MessagesApp.bundleID || WhatsAppApp.bundleIDs.contains(bundle)
}

/// Drop the stored thread once the user leaves Messages / WhatsApp Desktop.
public func keepChat(_ snap: Snapshot?, frontmost: String?) -> Snapshot? {
    macChatReads(frontmost) ? snap : nil
}
