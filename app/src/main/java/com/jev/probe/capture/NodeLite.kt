package com.jev.probe.capture

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo

/**
 * A plain, Android-free copy of one accessibility node. Parsers that read these
 * instead of AccessibilityNodeInfo can be unit-tested against `uiautomator
 * dump` fixtures (see src/test/.../DumpXml.kt).
 */
data class NodeLite(
    val id: String,   // viewIdResourceName, "" when absent
    val cls: String,
    val text: String,
    val desc: String,
    val left: Int, val top: Int, val right: Int, val bottom: Int,
    val editable: Boolean
)

/** Pre-order walk (the order uiautomator dump writes), capped at [limit] nodes. */
fun flatten(root: AccessibilityNodeInfo, limit: Int = 6000): List<NodeLite> {
    val out = ArrayList<NodeLite>()
    val stack = ArrayDeque<AccessibilityNodeInfo>()
    stack.addLast(root)
    val b = Rect()
    while (stack.isNotEmpty() && out.size < limit) {
        val n = stack.removeLast()
        n.getBoundsInScreen(b)
        val cls = n.className?.toString() ?: ""
        out.add(NodeLite(
            n.viewIdResourceName ?: "", cls, n.text?.toString() ?: "",
            n.contentDescription?.toString() ?: "",
            b.left, b.top, b.right, b.bottom,
            n.isEditable || cls == "android.widget.EditText"))
        for (i in n.childCount - 1 downTo 0) n.getChild(i)?.let { stack.addLast(it) }
    }
    return out
}

/** "me" when the bubble hugs the right edge more than the left. Compares edge
 *  gaps rather than the center point: a long incoming message crosses mid-screen. */
fun sideByEdges(left: Int, right: Int, width: Int): String =
    if (width - right < left) "me" else "other"

/** The thread name in the top bar: the topmost short, non-editable text that
 *  ends above the first message. Null when nothing qualifies. */
fun topTitle(nodes: List<NodeLite>, firstMsgTop: Int): String? =
    nodes.filter {
        it.text.isNotBlank() && it.text.length <= 40 && !it.editable &&
            it.bottom in 1..firstMsgTop
    }.minByOrNull { it.top }?.text?.trim()
