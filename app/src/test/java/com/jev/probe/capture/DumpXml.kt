package com.jev.probe.capture

import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element

/** Loads a `uiautomator dump` XML fixture as the same pre-order NodeLite list
 *  [flatten] produces on the device. The dump has no "editable" attribute, so
 *  EditText class stands in for it (flatten treats EditText as editable too). */
object DumpXml {
    private val BOUNDS = Regex("""\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]""")

    fun load(name: String): List<NodeLite> {
        val stream = DumpXml::class.java.classLoader!!.getResourceAsStream("dumps/$name")
            ?: error("missing fixture dumps/$name")
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(stream)
        val out = ArrayList<NodeLite>()
        fun walk(e: Element) {
            if (e.tagName == "node") {
                val b = BOUNDS.find(e.getAttribute("bounds"))!!.groupValues
                val cls = e.getAttribute("class")
                out.add(NodeLite(
                    e.getAttribute("resource-id"), cls, e.getAttribute("text"),
                    e.getAttribute("content-desc"),
                    b[1].toInt(), b[2].toInt(), b[3].toInt(), b[4].toInt(),
                    cls == "android.widget.EditText"))
            }
            val kids = e.childNodes
            for (i in 0 until kids.length) (kids.item(i) as? Element)?.let { walk(it) }
        }
        walk(doc.documentElement)
        return out
    }
}
