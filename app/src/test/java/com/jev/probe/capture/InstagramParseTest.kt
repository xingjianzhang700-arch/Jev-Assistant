package com.jev.probe.capture

import com.jev.probe.core.Msg
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InstagramParseTest {
    @Test fun threadReadsBothSidesInOrder() {
        val s = parseInstagram(DumpXml.load("instagram_thread.xml"), 1080)!!
        assertEquals("alex.r", s.title)
        assertEquals(listOf(
            Msg("other", "are we still on for tonight?"),
            Msg("me", "yes! 7pm?"),
            Msg("other", "perfect, see you there")
        ), s.messages)
        assertEquals("other", s.latestFrom)
    }

    @Test fun inboxIsNotAChat() {
        assertNull(parseInstagram(DumpXml.load("instagram_inbox.xml"), 1080))
    }

    @Test fun unreadableThreadGivesEmptySnapshotForOcrFallback() {
        val s = parseInstagram(DumpXml.load("instagram_empty_thread.xml"), 1080)
        assertNotNull(s)
        assertTrue(s!!.messages.isEmpty())
        assertEquals("alex.r", s.title)
    }
}
