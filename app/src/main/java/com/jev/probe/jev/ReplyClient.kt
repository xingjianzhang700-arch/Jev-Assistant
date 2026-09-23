package com.jev.probe.jev

import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Prefs
import com.jev.probe.core.kb.ChatContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * The generative route: any OpenAI-compatible `/chat/completions` endpoint.
 * Drafts the 3 candidate replies, and (D stage) summarizes text. Reads
 * replyBaseUrl / replyKey / replyModel from [Prefs].
 */
class ReplyClient(private val prefs: Prefs) {

    companion object {
        /** Shared with the laptop clients via shared/jev-brain.json (see BrainSyncTest). */
        const val DRAFT_SYSTEM =
            "You suggest replies in an instant-messaging chat. Output only a JSON array " +
                "containing exactly 3 candidate replies. Use three different strategies (for example: " +
                "one steady and receptive, one with a concrete action or commitment, one short and low-key). " +
                "Each under 40 words, casual and natural, like a real person texting. " +
                "Write in the same language the other person is writing in. " +
                "No explanations, nothing outside the JSON array."

        const val FALLBACK_REPLY = "One sec, let me check."

        fun draftUser(relationship: String, convo: String): String =
            "Relationship: ${relationship}\n\nRecent conversation:\n${convo}\n\nGive 3 candidate replies."
    }

    /**
     * Exactly 3 varied candidate replies, in the language of the conversation.
     *
     * @param ctx D-stage knowledge context. When present its background and
     *        history are prepended to the prompt with an instruction to stay
     *        consistent with them and invent nothing beyond them.
     */
    fun draft(snapshot: ChatSnapshot, relationship: String, ctx: ChatContext? = null): List<String> {
        val convo = snapshot.messages.takeLast(10).joinToString("\n") {
            (if (it.side == "me") "Me" else "Them") + ": " + it.text
        }
        val sys = DRAFT_SYSTEM
        val user = knowledgeBlock(relationship, ctx) + draftUser(relationship, convo)
        return parseThree(chat(sys, user, temperature = 0.8))
    }

    /** The background + history preamble; empty string when there is no context. */
    private fun knowledgeBlock(relationship: String, ctx: ChatContext?): String {
        ctx ?: return ""
        val background = ctx.background(relationship)
        val history = ctx.history
        if (background.isBlank() && history.isEmpty()) return ""
        val sb = StringBuilder()
        sb.append("Background and knowledge base about me and the other person. Replies must be ")
            .append("consistent with it and may cite its facts. Do not invent facts that are not in it.\n")
        if (background.isNotBlank()) sb.append(background).append('\n')
        if (history.isNotEmpty()) {
            sb.append("\nEarlier messages (newest last):\n")
            history.takeLast(prefs.contextHistoryCount.coerceIn(0, 100)).forEach {
                sb.append(if (it.side == "me") "Me: " else "Them: ").append(it.text).append('\n')
            }
        }
        sb.append('\n')
        return sb.toString()
    }

    /**
     * One plain chat round trip for the settings connectivity test. Deliberately
     * NOT [summarize]: the test should exercise the ordinary path, not whatever
     * the summary prompt happens to be.
     */
    fun ping(): String =
        chat("You are a connectivity test. Answer exactly as asked, no explanation.",
            "Reply with only the word: OK", temperature = 0.0).trim()

    /** Condense a block of text (used by the D-stage contact auto-summary). */
    fun summarize(text: String): String {
        if (text.isBlank()) return ""
        val sys = "You summarize chat logs. Condense the text into a third-person summary of at most " +
            "80 words, keeping only facts, preferences, commitments and to-dos. No commentary, " +
            "invent nothing. Output the summary only."
        return chat(sys, text, temperature = 0.2).trim()
    }

    /** One chat-completions round trip; returns the assistant message content. */
    private fun chat(system: String, user: String, temperature: Double): String {
        val url = prefs.replyEndpoint()
        val messages = JSONArray()
            .put(JSONObject().put("role", "system").put("content", system))
            .put(JSONObject().put("role", "user").put("content", user))
        val body = JSONObject()
            .put("model", prefs.replyModel)
            .put("messages", messages)
            .put("temperature", temperature)
        val resp = HttpJson.post(url, prefs.effectiveReplyKey(), body, Route.REPLY, HttpJson.headersFor(url))
        return resp.optJSONArray("choices")?.optJSONObject(0)
            ?.optJSONObject("message")?.optString("content") ?: ""
    }

    private fun parseThree(content: String): List<String> {
        val start = content.indexOf('[')
        val end = content.lastIndexOf(']')
        if (start >= 0 && end > start) {
            try {
                val arr = JSONArray(content.substring(start, end + 1))
                val out = ArrayList<String>()
                for (i in 0 until arr.length()) out.add(arr.getString(i).trim())
                if (out.size >= 3) return out.take(3)
                while (out.size < 3) out.add(FALLBACK_REPLY)
                return out
            } catch (_: Exception) { }
        }
        // Fallback: split lines.
        val lines = content.split("\n").map { it.trim().trimStart('-', '*', '1', '2', '3', '.', ' ', '"') }
            .filter { it.isNotBlank() }
        val out = lines.take(3).toMutableList()
        while (out.size < 3) out.add(FALLBACK_REPLY)
        return out
    }
}
