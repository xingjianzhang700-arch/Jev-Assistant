package com.jev.probe.capture

/** "8:11", "8:11 PM", "8：11" (full-width colon from Chinese UIs). */
private const val TIME = """\d{1,2}[:：]\d{2}(\s*(AM|PM|am|pm|上午|下午))?""" // cjk-ok

private val PURE_TIME = Regex(TIME)
private val TAIL_TIME = Regex("""\s*$TIME$""")

/** Receipts apps glue after a bubble. English ones must stand as a whole word. */
private val TAIL_RECEIPT = Regex("""(\s+|^)(Read|Unread|Seen|Delivered|Sent)$|(已读|未读)$""") // cjk-ok

/** Day words used as dividers, not as message text. */
private val DAY_WORDS = setOf("Yesterday", "Today", "昨天", "今天") // cjk-ok

/** A line that is only a clock time — a divider, never a message. */
internal fun isPureTime(s: String): Boolean = PURE_TIME.matches(s.trim())

/** Strip trailing read receipts and timestamps an app draws onto a bubble. */
internal fun cleanBubbleText(raw: String): String {
    var t = raw.trim()
    while (t.isNotEmpty()) {
        val next = TAIL_RECEIPT.find(t)?.let { t.substring(0, it.range.first).trim() }
            ?: TAIL_TIME.find(t)?.let { t.substring(0, it.range.first).trim() }
            ?: break
        t = next
    }
    return t
}

/** Timestamp or day divider text (used to keep them out of titles and bodies). */
internal fun looksLikeTimestamp(t: String): Boolean =
    Regex("""\d{1,2}[:：]\d{2}""").containsMatchIn(t) || // cjk-ok
        Regex("""\d+月\d+日""").containsMatchIn(t) || // cjk-ok
        DAY_WORDS.any { t == it || t.startsWith("$it ") }
