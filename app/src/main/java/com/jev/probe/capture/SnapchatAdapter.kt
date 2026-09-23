package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * Snapchat chat (com.snapchat.android). Ids are expected values, not yet verified
 * on a device — see src/test/resources/dumps/README.md.
 *
 * "In a thread" = the compose box `:id/chat_input_text_field` exists. Bodies are
 * `:id/chat_message_text`, using the node's text, or its content description when
 * the text is blank. Side comes from which screen edge the bubble hugs.
 */
class SnapchatAdapter : ChatAppAdapter {
    override val pkg = "com.snapchat.android"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseSnapchat(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseSnapchat(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id.endsWith(SC_COMPOSER) }) return null
    val bodies = nodes.mapNotNull { n ->
        if (!n.id.endsWith(SC_BODY)) return@mapNotNull null
        val t = n.text.ifBlank { n.desc }.trim()
        if (t.isEmpty()) null else n to t
    }.sortedBy { it.first.top }
    val title = nodes.firstOrNull { it.id.endsWith(SC_TITLE) && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.first?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { (n, t) -> Msg(sideByEdges(n.left, n.right, width), t) })
}

private const val SC_BODY = ":id/chat_message_text"
private const val SC_COMPOSER = ":id/chat_input_text_field"
private const val SC_TITLE = ":id/chat_title"
