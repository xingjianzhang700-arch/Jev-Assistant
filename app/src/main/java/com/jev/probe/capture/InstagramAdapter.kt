package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * Instagram Direct (com.instagram.android). Ids are the expected values, not yet verified on a device —
 * see src/test/resources/dumps/README.md for how to capture real dumps and confirm them.
 *
 * "In a thread" = the thread composer exists. The inbox has a search EditText
 * but never this id, so it returns null. Message bodies are TextViews with
 * [IG_BODY_ID]; side comes from which screen edge the bubble hugs.
 */
class InstagramAdapter : ChatAppAdapter {
    override val pkg = "com.instagram.android"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseInstagram(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseInstagram(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id == IG_COMPOSER_ID }) return null
    val bodies = nodes.filter { it.id == IG_BODY_ID && it.text.isNotBlank() }.sortedBy { it.top }
    val title = nodes.firstOrNull { it.id == IG_TITLE_ID && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { Msg(sideByEdges(it.left, it.right, width), it.text.trim()) })
}

private const val IG_BODY_ID = "com.instagram.android:id/direct_text_message_text_view"
private const val IG_COMPOSER_ID = "com.instagram.android:id/row_thread_composer_edittext"
private const val IG_TITLE_ID = "com.instagram.android:id/header_title"
