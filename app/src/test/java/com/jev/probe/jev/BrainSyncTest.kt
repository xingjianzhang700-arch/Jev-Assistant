package com.jev.probe.jev

import com.jev.probe.core.Prefs
import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * shared/jev-brain.json must equal what the Android sources say. The laptop
 * clients read that file, so this is what keeps all three on one wording.
 * Regenerate: UPDATE_BRAIN=1 ./gradlew --no-daemon :app:testDebugUnitTest --tests '*BrainSyncTest'
 * Keys not generated here (e.g. "labels") are kept as they are.
 */
class BrainSyncTest {
    private val file = File("../shared/jev-brain.json")   // test cwd is app/

    private fun expected(): JSONObject = JSONObject()
        .put("judge_url_default", Prefs.DEFAULT_JUDGE_BASE_OPENROUTER + "/alpha/decisions")
        .put("judge_model_default", Prefs.DEFAULT_JUDGE_MODEL_OPENROUTER)
        .put("reply_url_default", Prefs.DEFAULT_REPLY_BASE + "/chat/completions")
        .put("reply_model_default", Prefs.DEFAULT_REPLY_MODEL)
        .put("default_relationship", Prefs.DEFAULT_REL)
        .put("judge_questions", JevQuestions.judge())
        .put("rank_instructions", JevQuestions.rankQuestion(listOf("a", "b", "c"))
            .getJSONObject("best_reply").getString("instructions"))
        .put("draft_system", ReplyClient.DRAFT_SYSTEM)
        .put("draft_user_template", ReplyClient.draftUser("{relationship}", "{conversation}"))
        .put("fallback_reply", ReplyClient.FALLBACK_REPLY)

    private fun same(a: Any?, b: Any?): Boolean = if (a is JSONObject) a.similar(b) else a == b

    @Test fun sharedBrainMatchesAndroid() {
        val want = expected()
        if (System.getenv("UPDATE_BRAIN") == "1") {
            val merged = if (file.exists()) JSONObject(file.readText()) else JSONObject()
            want.keys().forEach { merged.put(it, want.get(it)) }
            file.parentFile.mkdirs()
            file.writeText(merged.toString(2) + "\n")
        }
        assertTrue("missing ${file.path}; run with UPDATE_BRAIN=1", file.exists())
        val have = JSONObject(file.readText())
        want.keys().forEach { k ->
            assertTrue("shared/jev-brain.json '$k' is stale; run with UPDATE_BRAIN=1", same(want.get(k), have.opt(k)))
        }
    }
}
