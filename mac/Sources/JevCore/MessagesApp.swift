import Foundation

/// Apple Messages (com.apple.MobileSMS). Fixture roles/ids are expected values,
/// not yet verified on a device — see mac/Fixtures/README.md.
public enum MessagesApp {
    public static let bundleID = "com.apple.MobileSMS"

    public static func isComposer(_ n: AXNode) -> Bool {
        if n.identifier == "messageBodyField" { return true }
        if n.identifier == "CKBalloonTextView" { return false }
        return n.editable && (n.role == "AXTextArea" || n.role == "AXTextField") && n.subrole != "AXSearchField"
    }

    public static func isBody(_ n: AXNode) -> Bool {
        let t = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.count > 2000 { return false }
        if looksLikeChrome(t) { return false }
        if n.identifier == "CKBalloonTextView" { return true }
        if n.editable { return false }
        if n.role == "AXTextArea" { return true }
        return false
    }

    private static func looksLikeChrome(_ t: String) -> Bool {
        let s = t.lowercased()
        if s == "search" || s == "today" || s == "yesterday" { return true }
        if s.hasPrefix("delivered") || s.hasPrefix("read") || s.hasPrefix("edited") { return true }
        return t.range(of: #"^\d{1,2}:\d{2}\s*(am|pm)?$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// nil = no conversation open; empty messages = open but unreadable.
    public static func parse(_ window: AXNode) -> Snapshot? {
        let all = window.flattened()
        guard all.contains(where: isComposer) else { return nil }
        let title = all.first(where: { $0.identifier == "ConversationTitle" })?.text
        if let area = all.first(where: { $0.identifier == "TranscriptCollectionView" }) {
            let balloons = area.flattened().filter(isBody).sorted { $0.y < $1.y }
            return Snapshot(title: title, messages: msgsFromBalloons(balloons))
        }
        // Older / fixture layout: bubbles live in AXScrollArea.
        let areas = all.filter { $0.role == "AXScrollArea" }.map { ($0, $0.flattened().filter(isBody)) }
        guard let best = areas.max(by: { $0.1.count != $1.1.count ? $0.1.count < $1.1.count : $0.0.w > $1.0.w }),
              !best.1.isEmpty else { return Snapshot(title: title, messages: []) }
        let area = best.0
        let msgs = msgsFromBalloons(best.1.sorted { $0.y < $1.y })
        let header = title ?? all.filter {
            $0.role == "AXStaticText" && !$0.text.isEmpty && $0.text.count <= 40 &&
                $0.y + $0.h <= area.y + 1 && $0.x >= area.x - 1 && $0.x < area.x + area.w
        }.max { $0.y < $1.y }?.text
        return Snapshot(title: header, messages: msgs)
    }

    /// Sides come from the outgoing trailing edge (right-aligned = me), not the
    /// transcript/window width — that frame is often far wider than the chat column.
    private static func msgsFromBalloons(_ balloons: [AXNode]) -> [Msg] {
        // Ignore emoji-only / tiny stickers when finding the trailing edge so a
        // centered reaction cannot invent a fake max-right and flip real text.
        let edgeIdx = balloons.indices.filter { !isDecorativeBalloon(balloons[$0].text) }
        let edgeBalls = edgeIdx.isEmpty ? balloons : edgeIdx.map { balloons[$0] }
        let lefts = edgeBalls.map(\.x)
        let rights = edgeBalls.map { $0.x + $0.w }
        let edgeSides = sidesByBalloonEdges(lefts: lefts, rights: rights)
        var sideByEdgeIndex: [Int: String] = [:]
        for (i, side) in zip(edgeIdx.isEmpty ? Array(balloons.indices) : edgeIdx, edgeSides) {
            sideByEdgeIndex[i] = side
        }
        return balloons.enumerated().map { i, b in
            let text = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let side = sideByEdgeIndex[i] {
                return Msg(side, text)
            }
            // Decorative: inherit the nearest text balloon's side (by index).
            let inherited = balloons.indices
                .filter { sideByEdgeIndex[$0] != nil }
                .min(by: { abs($0 - i) < abs($1 - i) })
                .flatMap { sideByEdgeIndex[$0] } ?? "other"
            return Msg(inherited, text)
        }
    }

    /// Single-emoji / blank stickers — keep as messages, but do not define column edges.
    private static func isDecorativeBalloon(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if t.count > 8 { return false }
        return t.unicodeScalars.allSatisfy { s in
            s.properties.isEmoji || s.properties.isEmojiPresentation || s == "\u{FE0F}" || s == "\u{200D}"
        }
    }
}
