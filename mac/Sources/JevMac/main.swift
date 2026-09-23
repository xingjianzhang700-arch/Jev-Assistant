import AppKit
import ApplicationServices
import JevCore

let args = CommandLine.arguments
if args.count >= 3, args[1] == "--dump" {
    guard AXIsProcessTrusted() else {
        print("Grant Accessibility access to the app running this command (System Settings → Privacy & Security → Accessibility), then retry.")
        exit(1)
    }
    guard let w = AXReader.chatWindow() else { print("Open Messages or WhatsApp with a conversation showing, then retry."); exit(1) }
    var budget = 8000
    let node = AXReader.tree(w, budget: &budget)
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try! enc.encode(node).write(to: URL(fileURLWithPath: args[2]))
    print("wrote \(args[2]) (\(8000 - budget) elements)")
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
