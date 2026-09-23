package com.jev.probe.capture

import com.jev.probe.core.Msg
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WhatsAppParseTest {
    @Test fun threadReadsBothSidesInOrder() {
        val s = parseWhatsApp(DumpXml.load("whatsapp_thread.xml"), 1080)!!
        assertEquals("Alex", s.title)
        assertEquals(listOf(
            Msg("other", "are we still on for tonight?"),
            Msg("me", "yes! 7pm?"),
            Msg("other", "perfect, see you there")
        ), s.messages)
        assertEquals("other", s.latestFrom)
    }

    @Test fun chatListIsNotAChat() {
        assertNull(parseWhatsApp(DumpXml.load("whatsapp_list.xml"), 1080))
    }

    @Test fun unreadableThreadGivesEmptySnapshotForOcrFallback() {
        val s = parseWhatsApp(DumpXml.load("whatsapp_empty_thread.xml"), 1080)
        assertNotNull(s)
        assertTrue(s!!.messages.isEmpty())
        assertEquals("Alex", s.title)
    }
}

class SnapchatParseTest {
    @Test fun threadReadsTextAndContentDescription() {
        val s = parseSnapchat(DumpXml.load("snapchat_thread.xml"), 1080)!!
        assertEquals("Alex", s.title)
        assertEquals(listOf(
            Msg("other", "are we still on for tonight?"),
            Msg("me", "yes! 7pm?"),
            Msg("other", "perfect, see you there")
        ), s.messages)
    }

    @Test fun friendListIsNotAChat() {
        assertNull(parseSnapchat(DumpXml.load("snapchat_list.xml"), 1080))
    }
}
