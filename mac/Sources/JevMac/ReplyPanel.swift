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
        if let m = s.mood {
            let pct = s.moodPct.map { " \($0)%" } ?? ""
            views.append(label("Mood: \(brainLabel("mood", m))\(pct)", bold: true))
        }
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
