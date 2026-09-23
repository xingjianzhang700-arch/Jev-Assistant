package com.jev.probe.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OcrTextTest {
    @Test fun pureTimeAcceptsBothLocales() {
        assertTrue(isPureTime("8:11"))
        assertTrue(isPureTime("10:29 PM"))
        assertTrue(isPureTime("10：29"))
        assertFalse(isPureTime("meet at 8:11 tomorrow"))
    }

    @Test fun cleanStripsEnglishReceiptsAndTime() {
        assertEquals("see you soon", cleanBubbleText("see you soon 9:41 AM Seen"))
        assertEquals("ok", cleanBubbleText("ok Delivered"))
    }

    @Test fun cleanStillStripsChineseReceipts() {
        assertEquals("好的", cleanBubbleText("好的 10:02 已读")) // cjk-ok
    }

    @Test fun cleanKeepsWordsThatOnlyEndLikeAReceipt() {
        assertEquals("I already read", cleanBubbleText("I already read"))
        assertEquals("Mis-Sent", cleanBubbleText("Mis-Sent"))
    }

    @Test fun timestampWordsInBothLocales() {
        assertTrue(looksLikeTimestamp("Yesterday"))
        assertTrue(looksLikeTimestamp("Today 9:41 AM"))
        assertTrue(looksLikeTimestamp("昨天")) // cjk-ok
        assertFalse(looksLikeTimestamp("Sam"))
    }
}
