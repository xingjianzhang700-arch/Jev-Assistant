package com.jev.probe.capture

import com.jev.probe.core.Msg
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MessagesParseTest {
    @Test fun conversationReadsBothSidesAndSkipsStatus() {
        val s = parseMessages(DumpXml.load("messages_thread.xml"), 1080)!!
        assertEquals("Mom", s.title)
        assertEquals(listOf(
            Msg("other", "Did you land?"),
            Msg("me", "Just now, waiting for bags"),
            Msg("other", "Call me when you're out")
        ), s.messages)
    }

    @Test fun conversationListIsNotAChat() {
        assertNull(parseMessages(DumpXml.load("messages_list.xml"), 1080))
    }
}
