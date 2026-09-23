package com.jev.probe.core.kb

import android.content.Context
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg
import com.jev.probe.core.Prefs

/**
 * On-device smoke test for the knowledge-base path, reachable from the settings
 * screen ("Self-check"). It exercises the parts that are easy to get quietly wrong —
 * name normalization across half/full-width member counts, note keyword hits,
 * and history de-duplication against what is already on screen — then removes
 * everything it created.
 *
 * It runs against the real [KbStore] (temporary note + contact, deleted at the
 * end) but a scratch [Prefs] file, so the user's own contextEnabled setting is
 * never touched.
 */
object KbSelfCheck {

    private const val SCRATCH_PREFS = "jev_kb_selfcheck_scratch"
    private const val BARE = "Test group"
    private const val TITLE = "Test group(12)"
    private const val ALIAS = "Test group（12）"          // full-width parens on purpose
    private const val PADDED = "  Test group  "
    private const val OLD_LINE = "Last week we agreed the self-check draft is due Friday"

    /** @return a one-line human-readable pass/fail summary. */
    fun run(context: Context): String {
        val failures = ArrayList<String>()

        // 0. Name normalization, checked first and on its own: its patterns are
        //    compiled in KbStore's class initializer, and a pattern the device's
        //    regex engine rejects used to take the whole class (and every
        //    analysis) down with an ExceptionInInitializerError.
        runCatching {
            listOf(TITLE, ALIAS, PADDED, BARE).forEach { raw ->
                val got = KbStore.normalizeName(raw)
                if (got != BARE)
                    failures.add("Name normalization failed: input ${raw} produced ${got}, expected ${BARE}")
            }
        }.onFailure {
            failures.add("Name normalization exception: ${it.javaClass.simpleName} ${it.message ?: ""}")
        }

        val store = KbStore.get(context)
        val noteId = KbStore.newId()
        val contactId = KbStore.newId()
        val prefs = scratchPrefs(context)
        try {
            prefs.contextEnabled = true
            prefs.contextHistoryCount = 30

            store.saveNote(Note(
                id = noteId,
                title = "Self-check temp note",
                content = "A made-up fact for the self-check: the project codename is Bluebird.",
                tags = listOf("test"),
                alwaysOn = false,
                enabled = true
            ))
            store.saveContact(Contact(
                id = contactId,
                name = "Self-check temp contact",
                aliases = listOf(ALIAS),
                apps = listOf("com.jev.probe"),
                relationship = "relationship text for the self-check"
            ))

            val snapshot = ChatSnapshot(TITLE, listOf(
                Msg("other", "Self-check message one: long enough to dedupe"),
                Msg("me", "Self-check message two: also long enough")
            ))

            // 1. contact hit via full-width alias + member-count stripping
            val ctx1 = ContextBuilder.build(context, snapshot, "com.jev.probe", prefs)
            if (ctx1.contact?.id != contactId)
                failures.add("Contact not matched (title ${TITLE} should match alias ${ALIAS})")

            // 2. note hit via tag "test" appearing in the conversation title
            if (ctx1.notes.none { it.id == noteId })
                failures.add("Note not matched (tag=test should match title ${TITLE})")

            // 3. the on-screen messages were recorded but not echoed back as history
            if (ctx1.history.isNotEmpty())
                failures.add("History dedupe failed: on-screen messages shouldn't appear in injected history (${ctx1.history.size} line(s))")
            if (store.logSize(contactId) != snapshot.messages.size)
                failures.add("History persisted count wrong: expected ${snapshot.messages.size}, got ${store.logSize(contactId)}")

            // 4. an older line survives, and re-reading the same screen adds nothing
            //    (screenBatch=false: this is a hand-injected line, not a capture,
            //    so it is not measured against the last screen we recorded)
            store.appendLog(contactId, listOf(
                LogEntry("other", OLD_LINE, System.currentTimeMillis() - 86_400_000L, "com.jev.probe")),
                screenBatch = false)
            val ctx2 = ContextBuilder.build(context, snapshot, "com.jev.probe", prefs)
            if (ctx2.history.size != 1 || ctx2.history.firstOrNull()?.text != OLD_LINE)
                failures.add("History injection wrong: expected exactly 1 old message, got ${ctx2.history.size}")
            if (store.logSize(contactId) != snapshot.messages.size + 1)
                failures.add("Duplicate capture was written a second time: ${store.logSize(contactId)} line(s)")

            // 5. background carries the fabricated fact into the prompt
            val background = ctx2.background("Default relationship")
            if (!background.contains("Bluebird")) failures.add("background is missing the note body")
            if (!background.contains("relationship text for the self-check")) failures.add("background is missing the contact relationship")

            // 6. history is off by default (opt-in only)
            prefs.contextEnabled = false
            if (ContextBuilder.build(context, snapshot, "com.jev.probe", prefs).history.isNotEmpty())
                failures.add("History was injected even though contextEnabled=false")
        } catch (e: Exception) {
            failures.add("Exception: ${e.javaClass.simpleName} ${e.message ?: ""}")
        } finally {
            runCatching { store.deleteNote(noteId) }
            runCatching { store.deleteContact(contactId) }
            runCatching {
                context.getSharedPreferences(SCRATCH_PREFS, Context.MODE_PRIVATE)
                    .edit().clear().commit()
            }
        }
        val counts = store.counts()
        return if (failures.isEmpty())
            "Self-check passed: contact match / note hit / history dedupe / budget injection all OK. " +
                "Knowledge base has ${counts.notes} notes, ${counts.contacts} contacts, ${counts.logLines} history lines."
        else "Self-check failed (${failures.size}): " + failures.joinToString("; ")
    }

    /** A [Prefs] bound to a throwaway SharedPreferences file (no migration, no log). */
    private fun scratchPrefs(context: Context): Prefs {
        context.getSharedPreferences(SCRATCH_PREFS, Context.MODE_PRIVATE).edit().clear().commit()
        return Prefs(context, SCRATCH_PREFS)
    }
}
