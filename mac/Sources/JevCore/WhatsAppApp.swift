import Foundation

/// WhatsApp Desktop. Bundle ids and roles are expected values, not yet verified
/// on a live window — see mac/Fixtures/README.md. Snapchat has no Mac app.
public enum WhatsAppApp {
    public static let bundleIDs = ["net.whatsapp.WhatsApp", "WhatsApp"]

    /// nil = no conversation open; empty messages = open but unreadable.
    /// Rows marked message-in / message-out keep that side. Otherwise the
    /// window is read with the same bubble rules as Apple Messages.
    public static func parse(_ window: AXNode) -> Snapshot? {
        let all = window.flattened()
        guard all.contains(where: MessagesApp.isComposer) else { return nil }
        let marked = all.filter(isMarkedRow).sorted { $0.y < $1.y }
        if marked.isEmpty { return MessagesApp.parse(window) }
        let msgs = marked.compactMap { row -> Msg? in
            let own = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = own.isEmpty
                ? row.children.lazy.map(\.text).first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                : own
            guard let text else { return nil }
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            let me = row.desc.contains("message-out") || row.identifier.contains("message-out")
            return Msg(me ? "me" : "other", body)
        }
        let firstY = marked.first?.y ?? .greatestFiniteMagnitude
        let title = all.filter {
            $0.role == "AXStaticText" && !$0.value.isEmpty && $0.value.count <= 40 && $0.y + $0.h <= firstY
        }.max { $0.y < $1.y }?.value
        return Snapshot(title: title, messages: msgs)
    }

    private static func isMarkedRow(_ n: AXNode) -> Bool {
        let tag = n.desc + " " + n.identifier
        return tag.contains("message-in") || tag.contains("message-out")
    }
}
