import AppKit
import ApplicationServices
import JevCore

/// Reads Messages through the Accessibility API. Never presses keys or buttons.
enum AXReader {
    private static let names = [kAXRoleAttribute, kAXSubroleAttribute, kAXIdentifierAttribute, kAXValueAttribute,
                                kAXTitleAttribute, kAXDescriptionAttribute, kAXPositionAttribute, kAXSizeAttribute,
                                kAXChildrenAttribute] as CFArray

    static func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    /// Messages or WhatsApp Desktop, whichever is in front (Accessibility path).
    static func chatWindow() -> AXUIElement? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              macChatReads(front.bundleIdentifier) else { return nil }
        let app = front
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        guard let w = attr(ax, kAXFocusedWindowAttribute) ?? attr(ax, kAXMainWindowAttribute) else { return nil }
        return (w as! AXUIElement)
    }

    private static func isEditableText(_ e: AXUIElement, role: String) -> Bool {
        guard role == "AXTextArea" || role == "AXTextField" else { return false }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(e, kAXValueAttribute as CFString, &settable)
        return settable.boolValue
    }

    /// One IPC round trip per element (CopyMultipleAttributeValues), capped by `budget`.
    static func tree(_ e: AXUIElement, depth: Int = 0, budget: inout Int) -> AXNode {
        budget -= 1
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(e, names, AXCopyMultipleAttributeOptions(rawValue: 0), &values)
        let v = (values as? [AnyObject]) ?? []
        func str(_ i: Int) -> String { i < v.count ? (v[i] as? String ?? "") : "" }
        var n = AXNode()
        n.role = str(0); n.subrole = str(1); n.identifier = str(2)
        n.value = str(3); n.title = str(4); n.desc = str(5)
        var p = CGPoint.zero, s = CGSize.zero
        if v.count > 7, CFGetTypeID(v[6]) == AXValueGetTypeID() { AXValueGetValue(v[6] as! AXValue, .cgPoint, &p) }
        if v.count > 7, CFGetTypeID(v[7]) == AXValueGetTypeID() { AXValueGetValue(v[7] as! AXValue, .cgSize, &s) }
        n.x = p.x; n.y = p.y; n.w = s.width; n.h = s.height
        n.editable = isEditableText(e, role: n.role)
        if depth < 60, budget > 0, v.count > 8, let kids = v[8] as? [AXUIElement] {
            n.children = kids.map { tree($0, depth: depth + 1, budget: &budget) }
        }
        return n
    }

    /// The compose field (same rule as MessagesApp.isComposer), for writing into.
    static func composer(_ e: AXUIElement, depth: Int = 0) -> AXUIElement? {
        let role = attr(e, kAXRoleAttribute) as? String ?? ""
        let subrole = attr(e, kAXSubroleAttribute) as? String ?? ""
        let ident = attr(e, kAXIdentifierAttribute) as? String ?? ""
        if ident == "CKBalloonTextView" { /* skip: those are bubbles, not the compose box */ }
        else if ident == "messageBodyField" || (subrole != "AXSearchField" && isEditableText(e, role: role)) { return e }
        guard depth < 60, let kids = attr(e, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for k in kids { if let hit = composer(k, depth: depth + 1) { return hit } }
        return nil
    }

    /// Put text in the compose field and read it back. Never sends.
    static func fill(_ text: String) -> Bool {
        guard let w = chatWindow(), let box = composer(w),
              AXUIElementSetAttributeValue(box, kAXValueAttribute as CFString, text as CFString) == .success
        else { return false }
        return (attr(box, kAXValueAttribute) as? String) == text
    }
}
