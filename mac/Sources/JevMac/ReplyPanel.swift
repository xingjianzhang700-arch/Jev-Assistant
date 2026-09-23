import AppKit
import JevCore

/// Floating, non-activating panel: status, Jev's read, and 3 replies with Fill / Copy.
@MainActor
final class ReplyPanel {
    var onFill: ((String) -> Void)?
    private let panel: NSPanel
    private let column = NSView()
    private var targets: [ClosureTarget] = []

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
                        styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.title = "Jev"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = column
    }

    func show(title: String?) {
        panel.title = "Jev · \(title ?? "Messages")"
        bringUp()
    }

    func status(_ text: String) { set([label(text, color: Self.muted)]) }

    func error(_ text: String) { set([label("Something went wrong", bold: true), label(text, color: Self.muted)]) }

    func show(summary s: Summary, replies: [RankedReply]) {
        // Old buttons disappear in set(); buttons hold targets weakly, so we keep the live ones.
        targets.removeAll()
        var views: [NSView] = []
        if let r = s.risk {
            let n = Int(r.rounded())
            views.append(label("Risk \(n) / 9", bold: true, size: 16, color: Self.riskColor(n)))
        }
        if !s.moods.isEmpty {
            views.append(moodRow(s.moods.map { m -> String in
                let name = brainLabel("mood", m.key)
                if let pct = m.pct { return "\(name) \(pct)%" }
                return name
            }))
        } else if let m = s.mood {
            let pct = s.moodPct.map { "\(brainLabel("mood", m)) \($0)%" } ?? brainLabel("mood", m)
            views.append(moodRow([pct]))
        }
        if let i = s.intent { views.append(label("Their real intent: \(brainLabel("intent", i))", bold: true)) }
        var bits: [String] = []
        if let n = s.needs { bits.append("Needs \(brainLabel("needs", n))") }
        if let a = s.bestAction { bits.append(brainLabel("action", a)) }
        if let ok = s.specificsOk { bits.append(ok >= 0.5 ? "OK to give specifics" : "Hold off on specifics") }
        if !bits.isEmpty { views.append(label(bits.joined(separator: " · "), size: 12, color: Self.muted)) }
        if let t = s.tensionResolved, t >= 0.7 { views.append(label("✓ Tension resolved", size: 12, color: Self.ok)) }
        views.append(label("Suggested replies", size: 12, color: Self.muted))
        views.append(contentsOf: replies.map(replyRow))
        set(views)
    }

    /// Separate non-wrapping mood chips with ≥16pt gaps — never one clutched string.
    private func moodRow(_ parts: [String]) -> NSView {
        let chips = (["Mood:"] + parts).map { plainLabel($0, bold: true) }
        return MoodStrip(labels: chips, spacing: 16)
    }

    private func replyRow(_ r: RankedReply) -> NSView {
        let fill = button("Fill") { [weak self] in self?.onFill?(r.text) }
        let copy = button("Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(r.text, forType: .string)
        }
        let buttons = NSStackView(views: [fill, copy])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let pct = label("\(Int((r.prob * 100).rounded()))%", bold: true, size: 13, color: Self.cyan)
        let body = label(r.text, size: 13)
        return ReplyCard(pct: pct, body: body, buttons: buttons)
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> NSButton {
        let t = ClosureTarget(action)
        targets.append(t)
        let b = NSButton(title: title, target: t, action: #selector(ClosureTarget.run))
        b.bezelStyle = .rounded
        b.controlSize = .small
        b.font = .systemFont(ofSize: 12)
        return b
    }

    private func plainLabel(_ s: String, bold: Bool = false, size: CGFloat = 13, color: NSColor? = nil) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        l.textColor = color ?? Self.ink
        l.maximumNumberOfLines = 1
        l.lineBreakMode = .byClipping
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }

    private func label(_ s: String, bold: Bool = false, size: CGFloat = 13, color: NSColor? = nil) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: s)
        l.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        l.textColor = color ?? Self.ink
        return l
    }

    private func set(_ views: [NSView]) {
        column.subviews.forEach { $0.removeFromSuperview() }
        let width: CGFloat = 360
        let pad: CGFloat = 14
        let gap: CGFloat = 8
        let innerW = width - pad * 2
        let heights = views.map { measure($0, width: innerW) }
        let total = pad * 2 + heights.reduce(0, +) + gap * CGFloat(max(heights.count - 1, 0))
        let maxH = (NSScreen.main?.visibleFrame.height ?? 800) - 48
        panel.setContentSize(NSSize(width: width, height: min(total, maxH)))
        column.frame = NSRect(x: 0, y: 0, width: width, height: panel.contentView?.bounds.height ?? total)
        // AppKit's origin is the bottom. Place the first row at the top.
        var y = column.bounds.height - pad
        for (v, h) in zip(views, heights) {
            y -= h
            v.frame = NSRect(x: pad, y: y, width: innerW, height: h)
            column.addSubview(v)
            y -= gap
        }
        column.needsLayout = true
        column.layoutSubtreeIfNeeded()
        bringUp()
    }

    private func measure(_ v: NSView, width: CGFloat) -> CGFloat {
        if let card = v as? ReplyCard { return card.measure(width: width) }
        if let strip = v as? MoodStrip { return strip.measure(width: width) }
        if let stack = v as? NSStackView {
            stack.frame.size.width = width
            return max(ceil(stack.fittingSize.height), 16)
        }
        if let l = v as? NSTextField {
            l.preferredMaxLayoutWidth = width
            return max(ceil(l.intrinsicContentSize.height), 16)
        }
        return 20
    }

    /// Writes the panel contents to a PNG (used by `--preview` for docs screenshots).
    func writePNG(to path: String) -> Bool {
        column.layoutSubtreeIfNeeded()
        let bounds = column.bounds
        guard bounds.width > 1, bounds.height > 1,
              let rep = column.bitmapImageRepForCachingDisplay(in: bounds) else { return false }
        column.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    private func bringUp() {
        guard !panel.isVisible else { return }
        if let f = NSScreen.main?.visibleFrame { panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - 380, y: f.maxY - 20)) }
        panel.orderFront(nil)
    }

    private static let ink = NSColor(name: "jevInk", dynamicProvider: { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 1)
            : NSColor(srgbRed: 0.09, green: 0.11, blue: 0.14, alpha: 1)
    })
    private static let muted = NSColor(name: "jevMuted", dynamicProvider: { a in
        a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.68, green: 0.73, blue: 0.78, alpha: 1)
            : NSColor(srgbRed: 0.33, green: 0.38, blue: 0.44, alpha: 1)
    })
    private static let cyan = NSColor(srgbRed: 0.18, green: 0.75, blue: 0.70, alpha: 1)
    private static let ok = NSColor(srgbRed: 0.25, green: 0.72, blue: 0.42, alpha: 1)

    private static func riskColor(_ n: Int) -> NSColor {
        if n >= 6 { return NSColor(srgbRed: 0.93, green: 0.34, blue: 0.31, alpha: 1) }
        if n >= 3 { return NSColor(srgbRed: 0.93, green: 0.62, blue: 0.18, alpha: 1) }
        return NSColor(srgbRed: 0.25, green: 0.75, blue: 0.42, alpha: 1)
    }
}

/// Horizontal mood chips with a fixed gap — layout is frame-based so spacing survives PNG capture.
/// Wraps rather than clutching when three moods do not fit on one row of the 360pt panel.
final class MoodStrip: NSView {
    private let labels: [NSTextField]
    private let spacing: CGFloat
    private var contentHeight: CGFloat = 16

    init(labels: [NSTextField], spacing: CGFloat) {
        self.labels = labels
        self.spacing = spacing
        super.init(frame: .zero)
        labels.forEach(addSubview)
    }

    required init?(coder: NSCoder) { nil }

    func measure(width: CGFloat) -> CGFloat {
        layout(width: width)
        return contentHeight
    }

    override func layout() {
        super.layout()
        layout(width: bounds.width)
    }

    private func layout(width: CGFloat) {
        // AppKit y grows up; place the first row at the top of this strip.
        var rows: [[(NSTextField, CGFloat, CGFloat)]] = [[]]
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [16]
        for lab in labels {
            let size = lab.intrinsicContentSize
            let w = ceil(size.width)
            let h = max(ceil(size.height), 16)
            let idx = rows.count - 1
            let used = rowWidths[idx]
            let next = used == 0 ? w : used + spacing + w
            if used > 0, next > width {
                rows.append([(lab, w, h)])
                rowWidths.append(w)
                rowHeights.append(h)
            } else {
                rows[idx].append((lab, w, h))
                rowWidths[idx] = next
                rowHeights[idx] = max(rowHeights[idx], h)
            }
        }
        let totalH = rowHeights.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        contentHeight = max(totalH, 16)
        var top = totalH
        for (r, row) in rows.enumerated() {
            let rowH = rowHeights[r]
            top -= rowH
            var x: CGFloat = 0
            for (i, item) in row.enumerated() {
                if i > 0 { x += spacing }
                item.0.frame = NSRect(x: x, y: top, width: item.1, height: item.2)
                x += item.1
            }
            if r + 1 < rows.count { top -= spacing }
        }
    }
}

/// One reply: percent, text, Fill / Copy. Height is measured, never stretched.
final class ReplyCard: NSView {
    let pct: NSTextField
    let body: NSTextField
    let buttons: NSStackView

    init(pct: NSTextField, body: NSTextField, buttons: NSStackView) {
        self.pct = pct
        self.body = body
        self.buttons = buttons
        super.init(frame: .zero)
        addSubview(pct)
        addSubview(body)
        addSubview(buttons)
    }

    required init?(coder: NSCoder) { nil }

    func measure(width: CGFloat) -> CGFloat {
        let textW = width - 20
        pct.preferredMaxLayoutWidth = textW
        body.preferredMaxLayoutWidth = textW
        let p = ceil(pct.intrinsicContentSize.height)
        let b = ceil(body.intrinsicContentSize.height)
        let btn = max(ceil(buttons.fittingSize.height), 24)
        return 8 + p + 4 + b + 6 + btn + 8
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fill = dark
            ? NSColor(srgbRed: 0.16, green: 0.18, blue: 0.22, alpha: 1)
            : NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1)
        let stroke = dark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.1)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override func layout() {
        super.layout()
        let textW = bounds.width - 20
        pct.preferredMaxLayoutWidth = textW
        body.preferredMaxLayoutWidth = textW
        var y = bounds.height - 8
        let p = ceil(pct.intrinsicContentSize.height)
        y -= p
        pct.frame = NSRect(x: 10, y: y, width: textW, height: p)
        y -= 4
        let b = ceil(body.intrinsicContentSize.height)
        y -= b
        body.frame = NSRect(x: 10, y: y, width: textW, height: b)
        y -= 6
        let btnH = max(ceil(buttons.fittingSize.height), 24)
        let btnW = max(ceil(buttons.fittingSize.width), 120)
        y -= btnH
        buttons.frame = NSRect(x: 10, y: max(y, 8), width: btnW, height: btnH)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }
}

/// NSButton target that runs a closure.
final class ClosureTarget: NSObject {
    private let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}
