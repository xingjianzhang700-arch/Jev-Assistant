package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * WhatsApp (com.whatsapp) and WhatsApp Business (com.whatsapp.w4b). Ids are expected
 * values, not yet verified on a device — see src/test/resources/dumps/README.md.
 *
 * "In a thread" = the compose box `:id/entry` exists. The chat list has a search
 * field and never this id. Message bodies are `:id/message_text`. Side comes from
 * which screen edge the bubble hugs.
 */
class WhatsAppAdapter : ChatAppAdapter {
    override val pkg = "com.whatsapp"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseWhatsApp(flatten(root), res.displayMetrics.widthPixels)
}

class WhatsAppBusinessAdapter : ChatAppAdapter {
    override val pkg = "com.whatsapp.w4b"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseWhatsApp(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseWhatsApp(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id.endsWith(WA_COMPOSER) }) return null
    val bodies = nodes.filter { it.id.endsWith(WA_BODY) && it.text.isNotBlank() }.sortedBy { it.top }
    val title = nodes.firstOrNull { it.id.endsWith(WA_TITLE) && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { Msg(sideByEdges(it.left, it.right, width), it.text.trim()) })
}

private const val WA_BODY = ":id/message_text"
private const val WA_COMPOSER = ":id/entry"
private const val WA_TITLE = ":id/conversation_contact_name"
