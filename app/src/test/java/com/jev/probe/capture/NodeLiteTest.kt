package com.jev.probe.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NodeLiteTest {
    @Test fun dumpLoadsInPreOrder() {
        val nodes = DumpXml.load("sample_bubbles.xml")
        assertEquals(5, nodes.size)
        assertEquals("Sam", nodes[1].text)
        assertEquals(true, nodes[4].editable)
    }

    @Test fun shortBubblesSideByEdge() {
        assertEquals("other", sideByEdges(150, 300, 1080))
        assertEquals("me", sideByEdges(800, 1040, 1080))
    }

    @Test fun longBubblesCrossingMidScreenKeepTheirSide() {
        // Incoming long message: starts after the avatar, ends past the middle.
        assertEquals("other", sideByEdges(150, 900, 1080))
        // Outgoing long message: starts left of middle, hugs the right edge.
        assertEquals("me", sideByEdges(200, 1040, 1080))
    }

    @Test fun titleIsTopmostShortTextAboveFirstMessage() {
        val nodes = DumpXml.load("sample_bubbles.xml")
        assertEquals("Sam", topTitle(nodes, 400))
    }

    @Test fun noTitleWhenNothingAboveFirstMessage() {
        val nodes = DumpXml.load("sample_bubbles.xml")
        assertNull(topTitle(nodes, 80))
    }
}
