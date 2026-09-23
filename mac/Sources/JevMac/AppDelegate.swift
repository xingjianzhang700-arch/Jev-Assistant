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
    private var generation = 0
    private var work: Task<Void, Never>?

    func applicationDidFinishLaunching(_ note: Notification) {
        if let button = status.button {
            button.title = "Jev"
            if let img = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Jev") {
                img.isTemplate = true
                button.image = img
                button.imagePosition = .imageLeading
            }
        }
        let menu = NSMenu()
        menu.addItem(item("Analyze now", #selector(analyzeNow)))
        menu.addItem(item("Why isn't it reading?", #selector(explainSetup)))
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

        let preview = CommandLine.arguments.contains("--preview")
        // Shows the system prompt once; the user grants access in System Settings.
        if !preview {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }

        if preview {
            panel.show(summary: Summary(
                intent: "close_topic", risk: 0, needs: "nothing", bestAction: "make_plan",
                specificsOk: 0.2, tensionResolved: 0.9, mood: "playful", moodPct: 64),
                replies: [
                    RankedReply(text: "Got it. Want me to snag both our tickets tomorrow? We can settle up after.", prob: 0.51),
                    RankedReply(text: "Sweet, thanks for the info. I'll grab mine soon. You heading home after the gym?", prob: 0.44),
                    RankedReply(text: "Cool cool. Good workout?", prob: 0.05),
                ])
        }

        if !preview && !UserDefaults.standard.bool(forKey: "didShowMenuHint") {
            UserDefaults.standard.set(true, forKey: "didShowMenuHint")
            let hint = NSAlert()
            hint.messageText = "Jev is in the menu bar"
            hint.informativeText = "There is no Dock icon. Look at the top-right of the screen for a speech bubble labeled Jev, to the left of the clock. If the menu bar is full, click the arrow that reveals hidden icons."
            hint.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            hint.runModal()
        }

        panel.onFill = { [weak self] text in self?.fill(text) }
        // ponytail: polls every 1.5 s while Messages or WhatsApp is frontmost. Switch to
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

    private func writeStatus(_ line: String) {
        let url = URL(fileURLWithPath: "/tmp/jev-status.txt")
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }

    private func tick() {
        if !AXIsProcessTrusted() {
            writeStatus("trusted=0 frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-") parsed=none")
            return
        }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
        guard let w = AXReader.chatWindow() else {
            writeStatus("trusted=1 frontmost=\(front) parsed=no-chat-window")
            if keepChat(current, frontmost: front) == nil && (current != nil || busy) {
                dropChat()
                panel.show(title: "Paused")
                panel.status(front.contains("firefox")
                    ? "Not reading this window. Instagram in Firefox isn't supported — use the Chrome extension, or bring Messages / WhatsApp Desktop to the front."
                    : "Not reading this window. The menu bar only follows Messages and WhatsApp Desktop.")
            }
            return
        }
        let t0 = Date()
        var budget = 8000
        let tree = AXReader.tree(w, budget: &budget)
        let parsed = WhatsAppApp.bundleIDs.contains(front) ? WhatsAppApp.parse(tree) : MessagesApp.parse(tree)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        if ms > 300 { print("jev: slow tick \(ms) ms, \(8000 - budget) elements") }  // timing only, no content
        guard let snap = parsed else {
            writeStatus("trusted=1 frontmost=\(front) parsed=nil")
            return
        }
        writeStatus("trusted=1 frontmost=\(front) parsed=\(snap.messages.isEmpty ? "empty" : "ok") count=\(snap.messages.count) latest=\(snap.latestFrom ?? "-")")
        current = snap
        guard snap.signature != lastSig else { return }
        lastSig = snap.signature
        panel.show(title: snap.title)
        if snap.messages.isEmpty { panel.status("Can't read this conversation's text."); return }
        if snap.latestFrom == "other" && Settings.auto { analyze(snap) }
        else { panel.status("Choose Analyze now in the Jev menu for suggestions.") }
    }

    private func dropChat() {
        generation += 1
        work?.cancel()
        work = nil
        busy = false
        current = nil
        lastSig = ""
    }

    @objc private func analyzeNow() {
        if !AXIsProcessTrusted() {
            panel.show(title: "Setup")
            panel.status("macOS has not allowed Jev to read Messages. System Settings → Privacy & Security → Accessibility → turn on Jev Assistant.")
            return
        }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if !macChatReads(front) {
            panel.show(title: "Paused")
            panel.status("Bring Messages or WhatsApp Desktop to the front. Instagram is the Chrome extension, not Firefox.")
            return
        }
        guard let s = current, !s.messages.isEmpty else {
            panel.show(title: "Setup")
            panel.status("No readable conversation yet. Click a thread in Messages or WhatsApp Desktop, leave that window in front, wait 2 seconds, then Analyze now.")
            return
        }
        analyze(s)
    }

    @objc private func explainSetup() {
        let trusted = AXIsProcessTrusted()
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        let n = current?.messages.count ?? 0
        panel.show(title: "Setup")
        panel.status("Accessibility \(trusted ? "on" : "OFF"). Front app \(front). Stored conversation \(n) messages. If Accessibility is off, enable Jev Assistant there and click a thread.")
    }

    private func analyze(_ s: Snapshot) {
        guard !busy else { return }
        let judgeKey = Settings.judgeKey
        guard !judgeKey.isEmpty else {
            panel.error("No Judge API key set. Choose Set Judge API key… in the Jev menu.")
            return
        }
        let stored = Settings.replyKey
        let replyKey = stored.isEmpty ? judgeKey : stored
        let rel = Settings.relationship
        busy = true
        panel.status("Analyzing…")
        let gen = generation
        work?.cancel()
        work = Task {
            defer { if gen == generation { busy = false } }
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
                guard !Task.isCancelled, gen == generation else { return }
                panel.show(summary: Prompt.summary(answers), replies: Prompt.ranked(best, candidates))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, gen == generation else { return }
                panel.error(error.localizedDescription)
            }
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

    private weak var askField: NSTextField?

    @objc private func pasteAskField() {
        guard let clip = NSPasteboard.general.string(forType: .string) else { return }
        askField?.stringValue = clip.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ask(_ title: String, _ current: String, secure: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Click Paste if ⌘V does nothing. Save with an empty box uses whatever is already on the clipboard."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 28))
        let field = (secure ? NSSecureTextField(frame: NSRect(x: 0, y: 2, width: 270, height: 24))
                            : NSTextField(frame: NSRect(x: 0, y: 2, width: 270, height: 24)))
        field.stringValue = current
        askField = field
        let paste = NSButton(frame: NSRect(x: 278, y: 0, width: 82, height: 28))
        paste.title = "Paste"
        paste.bezelStyle = .rounded
        paste.target = self
        paste.action = #selector(pasteAskField)
        box.addSubview(field)
        box.addSubview(paste)
        alert.accessoryView = box
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        let ok = alert.runModal() == .alertFirstButtonReturn
        NSApp.setActivationPolicy(.accessory)
        askField = nil
        guard ok else { return nil }
        let typed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func setJudgeKey() { if let v = ask("Judge API key (OpenRouter). Empty clears it.", "", secure: true) { Settings.judgeKey = v } }
    @objc private func setReplyKey() { if let v = ask("Reply API key. Empty reuses the Judge key.", "", secure: true) { Settings.replyKey = v } }
    @objc private func setRelationship() {
        if let v = ask("Who is the other person to you?", Settings.relationship, secure: false), !v.isEmpty { Settings.relationship = v }
    }
    @objc private func toggleAuto(_ sender: NSMenuItem) {
        Settings.auto.toggle()
        sender.state = Settings.auto ? .on : .off
    }
}
