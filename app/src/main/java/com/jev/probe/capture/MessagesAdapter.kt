package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * Google Messages (SMS/RCS, com.google.android.apps.messaging). Ids are the expected values,
 * not yet verified on a device — see src/test/resources/dumps/README.md for how to capture real
 * dumps and confirm them. Matched by suffix because the package prefix of ids has moved between
 * app versions.
 *
 * "In a conversation" = the compose box exists; the conversation list has none.
 * Bodies carry `:id/message_text`, so timestamps/status lines are excluded by id.
 * Side comes from which screen edge the bubble hugs.
 */
class MessagesAdapter : ChatAppAdapter {
    override val pkg = "com.google.android.apps.messaging"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseMessages(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseMessages(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id.endsWith(SMS_COMPOSER) }) return null
    val bodies = nodes.filter { it.id.endsWith(SMS_BODY) && it.text.isNotBlank() }.sortedBy { it.top }
    val title = nodes.firstOrNull { it.id.endsWith(SMS_TITLE) && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { Msg(sideByEdges(it.left, it.right, width), it.text.trim()) })
}

private const val SMS_BODY = ":id/message_text"
private const val SMS_COMPOSER = ":id/compose_message_text"
private const val SMS_TITLE = ":id/conversation_title"
