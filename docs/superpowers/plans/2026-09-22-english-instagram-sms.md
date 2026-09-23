# English Localization + Instagram & SMS Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Part 1 of 3.** This plan covers the Android phone app. The laptop versions are `2026-09-22-laptop-chrome-extension.md` (Instagram web + Google Messages web, which depends on Tasks 1–6 here) and `2026-09-22-laptop-mac-messages.md` (Apple Messages, which depends on the extension plan's Task 1). iPhone users get Jev through the laptop versions: iOS doesn't let apps read other apps' screens.

**Goal:** Turn the Jev chat assistant (Android, Kotlin) into an English-language product, and add Instagram Direct and SMS (Google Messages) to the chat apps it reads automatically.

**Architecture:** Jev is an accessibility service. It reads the foreground chat app's node tree through a per-app `ChatAppAdapter`, sends the conversation to a judge model (Jev) and a reply model, and shows ranked candidate replies in a floating overlay. The user taps "Fill" to put one in the input box and always presses send themselves. The two new adapters are thin: they flatten the node tree into plain `NodeLite` records and hand them to pure parser functions. Those parsers are unit-tested on the JVM against `uiautomator dump` XML fixtures. Everything downstream of the adapter (judge, overlay, fill) is app-agnostic and needs no change. Localization means translating UI strings, model prompts, comments and docs. Matchers for third-party apps' Chinese UI text stay, so WeChat, QQ, X and Feishu keep working.

**Tech Stack:** Kotlin 1.9.24, AGP 8.7.3, Gradle 8.9, JDK 17, minSdk 30 / compileSdk 35, classic Views (no Compose), ML Kit bundled text recognition, JUnit 4 (new, for JVM unit tests), Python 3 (checker script).

**Spec:** No separate spec. The user's request (2026-09-22) is the spec: *"download the repo locally, make everything English, make Jev work on Instagram and SMS messages."* The Requirements section below is its expansion, and executors should treat it as the spec.

## Requirements (the spec, expanded)

1. Every string a user sees in English: app name, main screen, settings, knowledge-base screen, overlay, toasts, notification, accessibility description, error messages.
2. Model prompts in English. Candidate replies come back in **the language the other person is writing in** (English for Instagram/SMS users, and Chinese chats still get Chinese replies).
3. Docs in English: README, CLAUDE.md, CHANGELOG, CONTRIBUTORS, `docs/`, `site/`, `tools/jev/` comments, prints and demo data. Code comments also in English.
4. When an Instagram Direct thread is open, Jev reads it automatically the way it reads WeChat, QQ, X and Feishu: incoming message → analysis → 3 ranked candidates → Fill.
5. The same for SMS in Google Messages (`com.google.android.apps.messaging`), the default SMS app on most non-Samsung Android phones, including global HyperOS.
6. Existing apps keep working (WeChat, QQ, X, Feishu), including on Chinese-language phones.

## Global Constraints

- **Never send a message.** Never `performAction` on any send button. Fill the input box and stop. (Hard rule from the upstream CLAUDE.md.)
- **No hooking.** No Xposed, no modifying target apps, no reading their databases. Accessibility service and screenshots only.
- **Nothing that touches money.** Never interact with transfer, red-packet or payment UI elements.
- **No secrets in files, logs or git.** No string starting with `sk-or-` anywhere. Logs carry counts and lengths, never message content (see `Log.d` in `ChatCaptureService.maybeCapture`).
- **Do not rename** `com.google.android.accessibility.selecttospeak.SelectToSpeakService` or its manifest entry. The disguise is what gets WeChat to expose its tree.
- **Keep third-party UI matchers.** Chinese literals that match *another app's* UI (e.g. `"新私信"`, `"聊天"`, `"你"`, `"昨天"`, `"已读"`) stay. Add the English equivalent beside each one, and mark the line with a trailing `// cjk-ok` comment.
- **Calibrated prompt text stays byte-identical:** `app/src/main/java/com/jev/probe/jev/JevQuestions.kt` and `tools/jev/questions.py`. The upstream notes say this wording "passed calibration", and they are already English except for example Chinese phrases. `tools/jev/fixtures/labeled_set.json` (the Chinese calibration set) and `NOTICE` (legal text, which already has an official English section) also stay.
- **Kotlin string templates:** write `${x}`, never `$x`, when the next character is a letter or CJK character. (`$x」` compiles as an unresolved reference; this happened upstream.)
- **Git:** work on local branch `english-instagram-sms`. Commit locally after each task. **Never push.** (The upstream CLAUDE.md rule 7 forbids agents committing at all. The repo owner decides whether to keep that rule; this plan assumes local commits are fine because the owner asked for the work.)
- Encoding UTF-8 everywhere. Python file I/O uses `encoding="utf-8"` explicitly.
- `minSdk 30`, `compileSdk/targetSdk 35`, `ndk.abiFilters = arm64-v8a` unchanged.

## Terminology glossary (use these exact English strings)

| Chinese | English |
|---|---|
| Jev助手 / Jev 助手 / Jev 聊天助手 | Jev Assistant |
| 填入 | Fill |
| 复制 / 已复制 | Copy / Copied |
| 分析当前对话 | Analyze this chat |
| 重新分析 | Re-analyze |
| 分析中… / 生成中… | Analyzing… / Drafting… |
| 候选回复（Jev 排序） | Suggested replies (ranked by Jev) |
| （未生成候选回复） | (No suggestions generated) |
| 回复接口出错：X | Reply API error: X |
| 出错了 | Something went wrong |
| 截屏识别一次 | Read screen once (OCR) |
| 把当前会话存为联系人 | Save this chat as a contact |
| 打开设置 / 设置 | Open settings / Settings |
| 隐藏助手（本次） | Hide assistant (this session) |
| 取消 | Cancel |
| 对方真实意图：X | Their real intent: X |
| 把握 N% | Confidence N% |
| 危险 a/b | Risk a/b |
| 很危险 / 偏危险 / 留神 / 安全 | High risk / Risky / Careful / Safe |
| 可给实质 / 先别给实质 | OK to give specifics / Hold off on specifics |
| 要X | Needs X |
| ✓ 紧张已缓解 | ✓ Tension resolved |
| 未用知识库 / 知识库 N 条 · 历史 M 条 | No knowledge used / Knowledge N · History M |
| INTENT map: 确认你在不在乎 / 在发泄情绪 / 要你办事 / 要个解释 / 随便聊聊 / 事情过去了 | checking you care / venting / wants action / wants an explanation / casual chat / topic closed |
| NEEDS map: 道歉 / 具体行动 / 解释 / 你的在乎 / （不用做什么） | an apology / a concrete action / an explanation / your care / (nothing) |
| ACTION map: 翻聊天记录 / 先道歉 / 给承诺 / 解释清楚 / 接住情绪 / 少说两句 / 定个安排 | check history / apologize first / commit / explain / acknowledge / say less / make a plan |
| 已填入，确认后自己发送 | Filled in. Review it, then send it yourself |
| 已复制，长按输入框粘贴 | Copied. Long-press the input box to paste |
| 无障碍权限 / 悬浮窗权限 | Accessibility access / Display over other apps |
| 自启动 + 省电无限制 | Autostart + no battery restrictions |
| 已就绪，可以用了 / 尚未就绪 | Ready to go / Not ready yet |
| 已开 / 未开 / 已设 / 未设 / ✓ 已开启 | On / Off / Set / Not set / ✓ Enabled |
| 知识库 | Knowledge base |
| 联系人 | Contact |
| 自检 | Self-check |
| 关系 | Relationship |
| 会话白名单 | Chat allowlist |
| 密钥 | API key |
| 判断接口 / 回复接口 / 视觉接口 | Judge API / Reply API / Vision API |
| 截屏失败：… | Screenshot failed: … |

For strings not in the table, translate plainly and briefly. Keep the upstream tone: short, direct, second person.

## File Structure

**Create**
- `tools/check_cjk.py`: lists every tracked line with Chinese ideographs that isn't allowlisted. This is the "test" for the translation tasks.
- `app/src/main/java/com/jev/probe/capture/NodeLite.kt`: `NodeLite` data class, `flatten()` (Android → plain records), and the pure helpers `sideByEdges()` and `topTitle()`.
- `app/src/main/java/com/jev/probe/capture/OcrText.kt`: pure OCR text cleanup moved out of the service (`isPureTime`, `cleanBubbleText`), made English-aware.
- `app/src/main/java/com/jev/probe/capture/InstagramAdapter.kt`: `InstagramAdapter` + pure `parseInstagram()`.
- `app/src/main/java/com/jev/probe/capture/MessagesAdapter.kt`: `MessagesAdapter` + pure `parseMessages()`.
- `app/src/test/java/com/jev/probe/capture/DumpXml.kt`: test helper that turns `uiautomator dump` XML into `List<NodeLite>`.
- `app/src/test/java/com/jev/probe/capture/NodeLiteTest.kt`, `OcrTextTest.kt`, `InstagramParseTest.kt`, `MessagesParseTest.kt`
- `app/src/test/resources/dumps/*.xml`: fixtures, both hand-written and real device dumps.
- `app/src/test/resources/dumps/README.md`: what was on screen for each real dump.

**Modify**
- `app/build.gradle.kts`: add JUnit.
- `app/src/main/java/com/jev/probe/capture/ChatCaptureService.kt`: use `OcrText`, register the new adapters, translate.
- `app/src/main/java/com/jev/probe/capture/ChatAppAdapter.kt`: English timestamp words, `cjk-ok` marks, translate comments.
- `app/src/main/java/com/jev/probe/jev/ReplyClient.kt`, `VisionClient.kt`, `JudgeClient.kt`, `HttpJson.kt`: English prompts and errors.
- `app/src/main/java/com/jev/probe/core/Prefs.kt`, `core/kb/KbModels.kt`, `core/kb/KbStore.kt`, `core/kb/KbSelfCheck.kt`: English defaults, labels and messages.
- `app/src/main/java/com/jev/probe/MainActivity.kt`, `SettingsActivity.kt`, `KnowledgeActivity.kt`, `overlay/OverlayController.kt`, `capture/KeepAliveService.kt`, `capture/ocr/ScreenCapture.kt`, `res/values/strings.xml`: UI strings.
- `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `CONTRIBUTORS.md`, `docs/*.md`, `site/*`, `tools/jev/*.py`, `tools/jev/TASK.md`: translate.

---

### Task 1: Toolchain, branch, CJK checker, baseline build

This Mac has no JDK and no Android SDK (checked 2026-09-22). The upstream build notes assume Windows paths (`H:\android\...`) and don't apply here.

**Files:**
- Create: `tools/check_cjk.py`
- Create (untracked, gitignored): `local.properties`

**Interfaces:**
- Produces: `python3 tools/check_cjk.py [pathspec...]`. It prints `path:line: text` for every offending line and exits 1 when there are any, 0 when clean. Later tasks use it as their failing/passing test.

- [ ] **Step 1: Create the branch**

```bash
cd "/Users/andy/Jev Chat/jev-chat-jarvis"
git checkout -b english-instagram-sms
```

- [ ] **Step 2: Install JDK 17 and Android command-line tools**

```bash
brew install openjdk@17
brew install --cask android-commandlinetools
```

Add these to the shell for the session (and to `~/.zshrc` if the owner agrees):

```bash
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$(brew --prefix)/share/android-commandlinetools"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
```

- [ ] **Step 3: Accept SDK licenses (HUMAN STEP, the repo owner must do this)**

Accepting license terms is the owner's decision, so the agent does not run this. The owner runs:

```bash
sdkmanager --licenses
```

- [ ] **Step 4: Install SDK packages**

```bash
sdkmanager "platforms;android-35" "build-tools;35.0.0" "platform-tools"
```

- [ ] **Step 5: Point Gradle at the SDK**

```bash
echo "sdk.dir=$ANDROID_HOME" > local.properties
```

(`local.properties` is already in `.gitignore`.)

- [ ] **Step 6: Baseline build must pass before any change**

Run: `./gradlew :app:assembleDebug`
Expected: `BUILD SUCCESSFUL`. If it fails, stop and report the error. Every later task assumes a green baseline.

- [ ] **Step 7: Write the CJK checker**

`tools/check_cjk.py`:

```python
#!/usr/bin/env python3
"""List tracked lines that still contain Chinese ideographs.

Usage: python3 tools/check_cjk.py [git pathspec ...]
Exit 1 if any non-allowlisted line is found, else 0.

Allowlisted:
- files whose Chinese is data we must not change (calibrated prompts,
  calibration fixtures, the bilingual legal NOTICE);
- any line ending in the marker `cjk-ok` (matchers for another app's
  Chinese UI, e.g. WeChat's "昨天").
"""
import re
import subprocess
import sys

CJK = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
ALLOW_FILES = {
    "NOTICE",
    "app/src/main/java/com/jev/probe/jev/JevQuestions.kt",
    "tools/jev/questions.py",
    "tools/jev/fixtures/labeled_set.json",
    "tools/check_cjk.py",
}
MARK = "cjk-ok"


def main(argv):
    files = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", *argv],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    bad = 0
    for path in files:
        if path in ALLOW_FILES:
            continue
        try:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
        except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
            continue  # binary (png/apk/jar) or gone
        for n, line in enumerate(lines, 1):
            if CJK.search(line) and not line.rstrip().endswith(MARK):
                print(f"{path}:{n}: {line.strip()[:120]}")
                bad += 1
    print(f"{bad} line(s) with Chinese text", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 8: Run it to see the starting count**

Run: `python3 tools/check_cjk.py; echo "exit=$?"`
Expected: roughly 1,000 lines listed, `exit=1`. Record the count in the commit message.

- [ ] **Step 9: Commit**

```bash
git add tools/check_cjk.py docs/superpowers/plans/2026-09-22-english-instagram-sms.md
git commit -m "chore: add CJK checker and English/Instagram/SMS plan"
```

---

### Task 2: Pure node model + JVM unit-test harness

The adapters take `AccessibilityNodeInfo`, which can't be constructed in a JVM unit test. The new adapters instead flatten the tree into `NodeLite` records and parse them with pure functions. Tests build the same records from `uiautomator dump` XML.

**Files:**
- Modify: `app/build.gradle.kts` (dependencies block)
- Create: `app/src/main/java/com/jev/probe/capture/NodeLite.kt`
- Create: `app/src/test/java/com/jev/probe/capture/DumpXml.kt`
- Create: `app/src/test/java/com/jev/probe/capture/NodeLiteTest.kt`
- Create: `app/src/test/resources/dumps/sample_bubbles.xml`

**Interfaces:**
- Produces:
  - `data class NodeLite(val id: String, val cls: String, val text: String, val desc: String, val left: Int, val top: Int, val right: Int, val bottom: Int, val editable: Boolean)`
  - `fun flatten(root: AccessibilityNodeInfo, limit: Int = 6000): List<NodeLite>`: pre-order, the same order `uiautomator dump` writes.
  - `fun sideByEdges(left: Int, right: Int, width: Int): String`: returns `"me"` or `"other"`.
  - `fun topTitle(nodes: List<NodeLite>, firstMsgTop: Int): String?`
  - Test helper `DumpXml.load(name: String): List<NodeLite>`, which reads `app/src/test/resources/dumps/<name>`.

- [ ] **Step 1: Add JUnit**

In `app/build.gradle.kts`, add to the `dependencies { }` block:

```kotlin
    testImplementation("junit:junit:4.13.2")
```

- [ ] **Step 2: Write the fixture**

`app/src/test/resources/dumps/sample_bubbles.xml` (same shape as `adb shell uiautomator dump` output):

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="x" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="Sam" resource-id="x:id/title" class="android.widget.TextView" package="x" content-desc="" bounds="[200,90][420,150]" />
    <node index="1" text="hey" resource-id="x:id/body" class="android.widget.TextView" package="x" content-desc="" bounds="[150,400][300,460]" />
    <node index="2" text="hi there" resource-id="x:id/body" class="android.widget.TextView" package="x" content-desc="" bounds="[800,500][1040,560]" />
    <node index="3" text="" resource-id="x:id/input" class="android.widget.EditText" package="x" content-desc="" bounds="[40,2200][900,2300]" />
  </node>
</hierarchy>
```

- [ ] **Step 3: Write the test helper**

`app/src/test/java/com/jev/probe/capture/DumpXml.kt`:

```kotlin
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
```

- [ ] **Step 4: Write the failing tests**

`app/src/test/java/com/jev/probe/capture/NodeLiteTest.kt`:

```kotlin
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
```

- [ ] **Step 5: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.NodeLiteTest'`
Expected: compilation FAILS with `Unresolved reference: NodeLite` / `sideByEdges` / `topTitle`.

- [ ] **Step 6: Implement**

`app/src/main/java/com/jev/probe/capture/NodeLite.kt`:

```kotlin
package com.jev.probe.capture

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo

/**
 * A plain, Android-free copy of one accessibility node. Parsers that read these
 * instead of AccessibilityNodeInfo can be unit-tested against `uiautomator
 * dump` fixtures (see src/test/.../DumpXml.kt).
 */
data class NodeLite(
    val id: String,   // viewIdResourceName, "" when absent
    val cls: String,
    val text: String,
    val desc: String,
    val left: Int, val top: Int, val right: Int, val bottom: Int,
    val editable: Boolean
)

/** Pre-order walk (the order uiautomator dump writes), capped at [limit] nodes. */
fun flatten(root: AccessibilityNodeInfo, limit: Int = 6000): List<NodeLite> {
    val out = ArrayList<NodeLite>()
    val stack = ArrayDeque<AccessibilityNodeInfo>()
    stack.addLast(root)
    val b = Rect()
    while (stack.isNotEmpty() && out.size < limit) {
        val n = stack.removeLast()
        n.getBoundsInScreen(b)
        val cls = n.className?.toString() ?: ""
        out.add(NodeLite(
            n.viewIdResourceName ?: "", cls, n.text?.toString() ?: "",
            n.contentDescription?.toString() ?: "",
            b.left, b.top, b.right, b.bottom,
            n.isEditable || cls == "android.widget.EditText"))
        for (i in n.childCount - 1 downTo 0) n.getChild(i)?.let { stack.addLast(it) }
    }
    return out
}

/** "me" when the bubble hugs the right edge more than the left. Compares edge
 *  gaps rather than the center point: a long incoming message crosses mid-screen. */
fun sideByEdges(left: Int, right: Int, width: Int): String =
    if (width - right < left) "me" else "other"

/** The thread name in the top bar: the topmost short, non-editable text that
 *  ends above the first message. Null when nothing qualifies. */
fun topTitle(nodes: List<NodeLite>, firstMsgTop: Int): String? =
    nodes.filter {
        it.text.isNotBlank() && it.text.length <= 40 && !it.editable &&
            it.bottom in 1..firstMsgTop
    }.minByOrNull { it.top }?.text?.trim()
```

- [ ] **Step 7: Run to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.NodeLiteTest'`
Expected: `BUILD SUCCESSFUL`, 5 tests passed.

- [ ] **Step 8: Commit**

```bash
git add app/build.gradle.kts app/src/main/java/com/jev/probe/capture/NodeLite.kt app/src/test
git commit -m "test: add NodeLite model and JVM unit-test harness for adapters"
```

---

### Task 3: English-aware OCR text cleanup and timestamp matching

The OCR fallback and the adapters drop timestamps and read receipts. Right now they only recognize Chinese forms (`已读`, `昨天`) and bare `8:11`. English UIs show `8:11 AM`, `Yesterday`, `Seen`, `Delivered`. These helpers currently sit as private members of the Android service, so move them into a pure file where they can be tested.

**Files:**
- Create: `app/src/main/java/com/jev/probe/capture/OcrText.kt`
- Create: `app/src/test/java/com/jev/probe/capture/OcrTextTest.kt`
- Modify: `app/src/main/java/com/jev/probe/capture/ChatCaptureService.kt`: delete the private `cleanBubbleText`, `PURE_TIME` and `TAIL_TIME` (in the companion object); change `groupOcrLines` to call `isPureTime`.
- Modify: `app/src/main/java/com/jev/probe/capture/ChatAppAdapter.kt:33-36` (`looksLikeTimestamp`)

**Interfaces:**
- Produces: `internal fun isPureTime(s: String): Boolean`, `internal fun cleanBubbleText(raw: String): String`, `internal fun looksLikeTimestamp(t: String): Boolean` (moved here from `ChatAppAdapter.kt`, where it was private).

- [ ] **Step 1: Write the failing tests**

`app/src/test/java/com/jev/probe/capture/OcrTextTest.kt`:

```kotlin
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
        assertEquals("好的", cleanBubbleText("好的 10:02 已读"))
    }

    @Test fun cleanKeepsWordsThatOnlyEndLikeAReceipt() {
        assertEquals("I already read", cleanBubbleText("I already read"))
    }

    @Test fun timestampWordsInBothLocales() {
        assertTrue(looksLikeTimestamp("Yesterday"))
        assertTrue(looksLikeTimestamp("Today 9:41 AM"))
        assertTrue(looksLikeTimestamp("昨天"))
        assertFalse(looksLikeTimestamp("Sam"))
    }
}
```

Note `cleanKeepsWordsThatOnlyEndLikeAReceipt`: the receipt words must be removed only as whole trailing words (`"… Read"`), never as a suffix of `"already read"`. The upstream `endsWith` stripping never had this problem because Chinese has no spaces.

- [ ] **Step 2: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.OcrTextTest'`
Expected: compilation FAILS, `Unresolved reference: isPureTime`.

- [ ] **Step 3: Implement**

`app/src/main/java/com/jev/probe/capture/OcrText.kt`:

```kotlin
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
```

In `ChatAppAdapter.kt`, delete lines 32–36 (the old private `looksLikeTimestamp` and its `/** Shared helpers. */` comment). Every caller in that file now resolves to the internal one in the same package.

In `ChatCaptureService.kt`:
- delete the private `cleanBubbleText` function (lines 425–437);
- in `groupOcrLines`, replace `!PURE_TIME.matches(it.text.trim())` with `!isPureTime(it.text)`;
- delete `PURE_TIME` and `TAIL_TIME` from the companion object.

The existing call `cleanBubbleText(lines.joinToString(" ") { it.text })` in `ocrByRects` now resolves to the package-level function and needs no edit.

- [ ] **Step 4: Run tests and a build**

Run: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
Expected: `BUILD SUCCESSFUL`; `OcrTextTest` 5 passed, `NodeLiteTest` 5 passed.

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/com/jev/probe/capture app/src/test
git commit -m "feat: recognize English timestamps and read receipts in capture and OCR"
```

---

### Task 4: English model prompts; replies in the chat's language

**Files:**
- Modify: `app/src/main/java/com/jev/probe/jev/ReplyClient.kt`
- Modify: `app/src/main/java/com/jev/probe/jev/VisionClient.kt:36-37`
- Modify: `app/src/main/java/com/jev/probe/core/kb/KbModels.kt:68-77`
- Modify: `app/src/main/java/com/jev/probe/core/Prefs.kt:284`

**Interfaces:**
- Consumes: nothing new. Function signatures stay exactly as they are (`draft`, `ping`, `summarize`, `ChatContext.background`).
- Produces: nothing new.

The testable guarantee here is "no Chinese left in these files", which the checker covers. Reply quality is checked on-device in Task 9.

- [ ] **Step 1: Run the checker to see it fail**

Run: `python3 tools/check_cjk.py app/src/main/java/com/jev/probe/jev/ReplyClient.kt app/src/main/java/com/jev/probe/jev/VisionClient.kt app/src/main/java/com/jev/probe/core/kb/KbModels.kt app/src/main/java/com/jev/probe/core/Prefs.kt`
Expected: lines listed, exit 1.

- [ ] **Step 2: Rewrite `ReplyClient.kt` prompts**

Replace the bodies as follows. Signatures and the JSON handling stay the same.

In `draft`:

```kotlin
        val convo = snapshot.messages.takeLast(10).joinToString("\n") {
            (if (it.side == "me") "Me" else "Them") + ": " + it.text
        }
        val sys = "You suggest replies in an instant-messaging chat. Output only a JSON array " +
            "containing exactly 3 candidate replies. Use three different strategies (for example: " +
            "one steady and receptive, one with a concrete action or commitment, one short and low-key). " +
            "Each under 40 words, casual and natural, like a real person texting. " +
            "Write in the same language the other person is writing in. " +
            "No explanations, nothing outside the JSON array."
        val user = knowledgeBlock(relationship, ctx) +
            "Relationship: ${relationship}\n\nRecent conversation:\n${convo}\n\nGive 3 candidate replies."
```

In `knowledgeBlock`:

```kotlin
        sb.append("Background and knowledge base about me and the other person. Replies must be ")
            .append("consistent with it and may cite its facts. Do not invent facts that are not in it.\n")
        if (background.isNotBlank()) sb.append(background).append('\n')
        if (history.isNotEmpty()) {
            sb.append("\nEarlier messages (newest last):\n")
            history.takeLast(prefs.contextHistoryCount.coerceIn(0, 100)).forEach {
                sb.append(if (it.side == "me") "Me: " else "Them: ").append(it.text).append('\n')
            }
        }
```

`ping`:

```kotlin
    fun ping(): String =
        chat("You are a connectivity test. Answer exactly as asked, no explanation.",
            "Reply with only the word: OK", temperature = 0.0).trim()
```

`summarize`:

```kotlin
        val sys = "You summarize chat logs. Condense the text into a third-person summary of at most " +
            "80 words, keeping only facts, preferences, commitments and to-dos. No commentary, " +
            "invent nothing. Output the summary only."
```

In `parseThree`, replace both occurrences of `"（稍等，我看下）"` with `"One sec, let me check."`. Change the doc comment `Exactly 3 varied candidate replies in Chinese.` to `Exactly 3 varied candidate replies, in the language of the conversation.`

- [ ] **Step 3: `VisionClient.kt` prompt**

Replace lines 36–37 with:

```kotlin
        "You transcribe chat screenshots. Transcribe the chat bubbles top to bottom, one per line, " +
            "as `Me: text` or `Them: text`. Output only the transcript, no explanation."
```

`VisionClient` returns the transcript as plain text and has no prefix parser, so nothing else needs to change. Translate the doc-comment reference `"OCR 分层"` to `"OCR layers"`.

- [ ] **Step 4: `KbModels.kt` background labels**

Lines 74–77: `"关系："` → `"Relationship: "`, `"关于"` + name + `"："` → `"About "` + name + `": "`, `"过往摘要："` → `"Past summary: "`. Translate the two doc comments (lines 8 and 68) using the glossary.

- [ ] **Step 5: `Prefs.kt` default relationship**

```kotlin
        const val DEFAULT_REL = "The other person is my partner; from=me is what I sent, from=other is what they sent"
```

(Existing installs keep whatever they saved. Only fresh installs see the new default.)

- [ ] **Step 6: Checker and build pass**

Run: `python3 tools/check_cjk.py app/src/main/java/com/jev/probe/jev/ReplyClient.kt app/src/main/java/com/jev/probe/jev/VisionClient.kt app/src/main/java/com/jev/probe/core/kb/KbModels.kt app/src/main/java/com/jev/probe/core/Prefs.kt && ./gradlew :app:assembleDebug`
Expected: `0 line(s) with Chinese text`, `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit**

```bash
git add app/src/main/java/com/jev/probe/jev app/src/main/java/com/jev/probe/core
git commit -m "feat: English model prompts; replies follow the conversation's language"
```

---

### Task 5: English UI strings and code comments across the app

**Files (all under `app/src/main/`):**
- `res/values/strings.xml`
- `java/com/jev/probe/MainActivity.kt` (17 lines), `SettingsActivity.kt` (82), `KnowledgeActivity.kt` (59)
- `java/com/jev/probe/overlay/OverlayController.kt` (38)
- `java/com/jev/probe/capture/ChatCaptureService.kt` (remaining toasts, `OCR_NOTE`, comments), `ChatAppAdapter.kt` (comments + matcher marks), `KeepAliveService.kt`, `ocr/ScreenCapture.kt`
- `java/com/jev/probe/core/kb/KbStore.kt`, `KbSelfCheck.kt`
- `java/com/jev/probe/jev/JudgeClient.kt`, `HttpJson.kt`

**Interfaces:** none change. Strings only.

- [ ] **Step 1: Run the checker to see it fail**

Run: `python3 tools/check_cjk.py app/`
Expected: about 300 lines listed, exit 1.

- [ ] **Step 2: `strings.xml`**

```xml
<resources>
    <string name="app_name">Jev Assistant</string>
    <string name="a11y_desc_disguised">Reads the text of the open chat window to suggest replies. Never sends messages on its own.</string>
</resources>
```

- [ ] **Step 3: Third-party UI matchers in `ChatAppAdapter.kt`: keep, add English, mark**

These lines match other apps' Chinese UI. Keep the Chinese and append ` // cjk-ok`. Where English is missing, add it:

```kotlin
            if (desc == "新私信" || desc == "New message") hasNewDmMarker = true // cjk-ok
...
                if (text == "私信" || text == "Message" || text == "发送私信") hasDmLabel = true // cjk-ok
                if (text == "聊天" || text == "Messages") sawListHeading = true // cjk-ok
...
        val msgs = rows.map { Msg(if (it.sender == "你" || it.sender == "You") "me" else "other", it.text) } // cjk-ok
```

In `parseXDesc`, the tail list `arrayOf("Read。", "Read", "已读。", "已读")` and the regexes `X_TAIL_TIME` and `WECHAT_TITLE_EXCLUDE_PUNCT` get ` // cjk-ok`. Also add `"Seen"` to that tail list. Translate every other Chinese comment in the file. In KDoc examples that quote real X desc strings (lines 387–391, 427–435), keep the quoted sample and put an English gloss after it, e.g. `"你：他这个东西开源应该问题不大。。。Read。" (You: open-sourcing it should be fine)`, and end each such line with `cjk-ok`.

- [ ] **Step 4: `ChatCaptureService.kt`**

- `TRANSIENT_TITLE_WORDS`: keep the list and put ` // cjk-ok` on each line that has Chinese.
- `OCR_NOTE` → `"OCR can't tell sides apart; every message is treated as theirs"`.
- Toasts/errors (use the glossary): `"当前会话没有标题，存不了"` → `"This chat has no title, so it can't be saved"`; `"当前会话标题还没加载出来，稍后再试"` → `"The chat title hasn't loaded yet. Try again in a moment"`; `"保存失败：${...}"` → `"Save failed: ${...}"`; `"未设置判断接口密钥，去设置里填"` → `"No Judge API key set. Add one in Settings"`; `"这一屏没认出文字"` → `"No text recognized on this screen"`; plus the two fill toasts from the glossary.
- Translate every comment that quotes a Chinese UI label, e.g. `"截屏识别一次"` → `"Read screen once (OCR)"`.

- [ ] **Step 5: Overlay, activities, notification, screenshot errors, KB store**

Translate every Chinese literal and comment in the files listed above, using the glossary for any term it covers. `ScreenCapture.humanMessage` for each code:

```kotlin
            CODE_THROTTLED -> "Screenshots too frequent"
            CODE_TIMEOUT -> "Screenshot timed out"
            1 -> "Screenshot failed: internal error (the system refused; this accessibility service may not be allowed to take screenshots)"
            2 -> "Screenshot failed: the accessibility service doesn't declare screenshot capability (turn accessibility off and on again in Settings)"
            3 -> "Screenshot failed: too soon after the last one, wait a second"
            4 -> "Screenshot failed: no valid display"
            6 -> "Screenshot failed: the window is hidden or protected (FLAG_SECURE), so it can't be captured"
            else -> "Screenshot failed (code ${code})"
```

`KbStore` messages: `"已存为联系人「${display}」"` → `"Saved as contact \"${display}\""`; `"联系人「${existing.name}」已存在"` → `"Contact \"${existing.name}\" already exists"`; `"已并入联系人「${existing.name}」"` → `"Merged into contact \"${existing.name}\""`.

`MainActivity` subtitle (line 66): `"Reads the other person's messages beside your chat app (WeChat, QQ, X, Feishu, Instagram, Messages) and suggests replies. You always press send yourself."` It names Instagram and Messages now, ahead of Tasks 7–8. If those tasks slip, remove the two names before release.

- [ ] **Step 6: `KbSelfCheck.kt`: translate data and assertions together**

The self-check writes fixture data and then asserts on it with `contains(...)`. Translate each constant **and** its matching check in the same edit:

```kotlin
    private const val BARE = "Test group"
    private const val TITLE = "Test group(12)"
    private const val ALIAS = "Test group（12）"          // full-width parens on purpose
    private const val PADDED = "  Test group  "
    private const val OLD_LINE = "Last week we agreed the self-check draft is due Friday"
```

Note content `"A made-up fact for the self-check: the project codename is Bluebird."`, tag `"test"` (the title must contain the tag. `ContextBuilder` compares through `KbStore.normalizeText`, which lowercases, so `"test"` matches `"Test group(12)"`), relationship `"relationship text for the self-check"`. Then the assertions become `background.contains("Bluebird")` and `background.contains("relationship text for the self-check")`. The messages become `"Self-check message one: long enough to dedupe"` / `"Self-check message two: also long enough"`. Translate every failure message. The success text: `"Self-check passed: contact match / note hit / history dedupe / budget injection all OK. Knowledge base has ${counts.notes} notes, ${counts.contacts} contacts, ${counts.logLines} history lines."`; failure prefix: `"Self-check failed (${failures.size}): "`, joined with `"; "`.

- [ ] **Step 7: Checker, build, tests pass**

Run: `python3 tools/check_cjk.py app/ && ./gradlew :app:testDebugUnitTest :app:assembleDebug`
Expected: `0 line(s) with Chinese text`, `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add app/src
git commit -m "feat: English UI strings, messages and comments throughout the app"
```

---

### Task 6: Translate docs, site and Python tools

**Files:** `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `CONTRIBUTORS.md`, `docs/acceptance.md`, `docs/probe_spec.md`, `docs/v1.3-plan.md`, `docs/v1.3-morning-checklist.md`, `site/index.html`, `site/main.js`, `site/style.css`, `tools/jev/TASK.md`, `tools/jev/demo_meme.py`, `tools/jev/probe_background_field.py`, `tools/jev/calibrate.py`, `tools/jev/jev_client.py`

**Interfaces:** none.

- [ ] **Step 1: Run the checker to see it fail**

Run: `python3 tools/check_cjk.py README.md CLAUDE.md CHANGELOG.md CONTRIBUTORS.md docs site tools`
Expected: about 700 lines, exit 1.

- [ ] **Step 2: Translate**

Rules:
- Translate faithfully. Keep headings, tables, links, code blocks and image references in place.
- `site/index.html`: set `<html lang="en">`. Translate visible text, `alt`, `title`, `meta` description.
- `CLAUDE.md`: translate everything. Keep the hard constraints numbered exactly as upstream. Update the "Key background" section with a line for Instagram and Google Messages that points at `app/src/test/resources/dumps/README.md`. Replace the Windows-only toolchain paths with the macOS setup from Task 1. Keep the original Windows paths as a note for Windows builders.
- `README.md`: the tagline becomes: *"A conversation copilot on your phone: in WeChat / QQ / X / Feishu / Instagram / SMS it reads the other person, suggests replies, and fills the input box in one tap. Whether to send is up to you. Non-invasive: it only reads the screen, with no hooking and no app modification."* Add Instagram and Messages to the supported-apps list.
- In the Python demos (`demo_meme.py`, `probe_background_field.py`), translate the sample conversations into natural English with the same meaning. They are demos, not calibration data. Leave `questions.py` and `fixtures/labeled_set.json` alone (allowlisted).
- `docs/v1.3-*.md` are historical design notes. Translate them as they are, and don't update their content.

- [ ] **Step 3: Full-repo checker passes**

Run: `python3 tools/check_cjk.py; echo "exit=$?"`
Expected: `0 line(s) with Chinese text`, `exit=0`.

- [ ] **Step 4: Python tools still parse**

Run: `python3 -m py_compile tools/jev/*.py && echo ok`
Expected: `ok`.

- [ ] **Step 5: Commit**

```bash
git add -A README.md CLAUDE.md CHANGELOG.md CONTRIBUTORS.md docs site tools
git commit -m "docs: translate README, CLAUDE.md, docs, site and tools to English"
```

---

### Task 7: Capture real Instagram and Google Messages dumps (HUMAN + agent)

This step needs a physical Android phone with USB debugging on and Instagram and Google Messages logged in. Upstream used a Xiaomi 14 (1200×2670). Resource-ids in Tasks 8–9 are **expected** values, and these dumps are what confirm or correct them.

**Files:**
- Create: `app/src/test/resources/dumps/instagram_thread_real.xml`, `instagram_inbox_real.xml`, `messages_thread_real.xml`, `messages_list_real.xml`
- Create: `app/src/test/resources/dumps/README.md`

**Interfaces:**
- Produces: a table in `dumps/README.md` with the confirmed ids for each app (body, composer, title), the screen width, and for each thread dump the exact visible messages top to bottom with sides. Tasks 8–9 read their constants and real-dump assertions from it.

- [ ] **Step 1: For each of the 4 screens, open it on the phone, then dump**

```bash
adb shell uiautomator dump /sdcard/d.xml && adb pull /sdcard/d.xml app/src/test/resources/dumps/instagram_thread_real.xml
```

(Repeat with the right filename per screen: Instagram DM thread, Instagram DM inbox, Messages conversation, Messages conversation list.) Pick threads that have at least one message from each side, with the newest from the other person. **Use a test conversation.** These files get committed, so they must not contain private messages. Edit any real names or text in the XML before committing, and keep the bounds as they are.

- [ ] **Step 2: Check the dump isn't blank**

Run: `grep -c '<node' app/src/test/resources/dumps/instagram_thread_real.xml`
Expected: dozens of nodes or more. If it's 1–2 (an empty root, which is what WeChat does to ordinary services), **stop and report**. The app would then need the in-app probe route from `docs/probe_spec.md`, and the plan changes. Until then, the bubble menu's "Read screen once (OCR)" still works on that app.

- [ ] **Step 3: List the ids**

```bash
grep -o 'resource-id="[^"]*"' app/src/test/resources/dumps/instagram_thread_real.xml | sort | uniq -c | sort -rn | head -40
```

Find which id carries the message text (it appears once per visible message), which id the composer EditText has, and which id has the thread name. Do the same for Messages. If message text lives in `content-desc` instead of `text` (Compose UI, as in X), note that. The Task 8/9 parser then reads `desc` instead of `text`.

- [ ] **Step 4: Write `dumps/README.md`**

```markdown
# Device dumps

| App | Version | Device / width | Body id | Composer id | Title id | Text in |
|---|---|---|---|---|---|---|
| Instagram | <ver> | <device> / <px> | ... | ... | ... | text / content-desc |
| Google Messages | <ver> | <device> / <px> | ... | ... | ... | text / content-desc |

## instagram_thread_real.xml
On screen, top to bottom:
1. other: "..."
2. me: "..."
...
```

- [ ] **Step 5: Commit**

```bash
git add app/src/test/resources/dumps
git commit -m "test: add real Instagram and Google Messages UI dumps"
```

---

### Task 8: Instagram Direct adapter

**Files:**
- Create: `app/src/main/java/com/jev/probe/capture/InstagramAdapter.kt`
- Create: `app/src/test/java/com/jev/probe/capture/InstagramParseTest.kt`
- Create: `app/src/test/resources/dumps/instagram_thread.xml`, `instagram_inbox.xml`, `instagram_empty_thread.xml`
- Modify: `app/src/main/java/com/jev/probe/capture/ChatCaptureService.kt:46` (adapters list)

**Interfaces:**
- Consumes: `NodeLite`, `flatten`, `sideByEdges`, `topTitle` (Task 2); `ChatAppAdapter`, `ChatSnapshot`, `Msg` (existing).
- Produces: `class InstagramAdapter : ChatAppAdapter` with `pkg = "com.instagram.android"`; `internal fun parseInstagram(nodes: List<NodeLite>, width: Int): ChatSnapshot?`.

Adapter contract (from `ChatAppAdapter.kt`): return `null` when not in a thread; return a snapshot with **empty** messages when in a thread but no text is readable (this triggers the OCR fallback); otherwise return the messages top to bottom.

- [ ] **Step 1: Hand-written fixtures** (width 1080, using the expected ids. If Task 7 found different ids, use those here and in the constants)

`instagram_thread.xml`:

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.instagram.android" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="alex.r" resource-id="com.instagram.android:id/header_title" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[220,110][460,170]" />
    <node index="1" text="Today 7:02 PM" resource-id="" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[400,300][680,350]" />
    <node index="2" text="are we still on for tonight?" resource-id="com.instagram.android:id/direct_text_message_text_view" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[140,400][760,470]" />
    <node index="3" text="yes! 7pm?" resource-id="com.instagram.android:id/direct_text_message_text_view" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[780,520][1040,590]" />
    <node index="4" text="perfect, see you there" resource-id="com.instagram.android:id/direct_text_message_text_view" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[140,640][700,710]" />
    <node index="5" text="" resource-id="com.instagram.android:id/row_thread_composer_edittext" class="android.widget.EditText" package="com.instagram.android" content-desc="" bounds="[160,2250][860,2330]" />
  </node>
</hierarchy>
```

`instagram_inbox.xml` (DM list: it has a search EditText but no thread composer):

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.instagram.android" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="" resource-id="com.instagram.android:id/search_edit_text" class="android.widget.EditText" package="com.instagram.android" content-desc="" bounds="[40,200][1040,280]" />
    <node index="1" text="alex.r" resource-id="com.instagram.android:id/row_inbox_username" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[200,360][500,410]" />
    <node index="2" text="perfect, see you there · 2m" resource-id="com.instagram.android:id/row_inbox_digest" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[200,420][900,470]" />
  </node>
</hierarchy>
```

`instagram_empty_thread.xml` (a thread whose bodies aren't readable, e.g. only photos):

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.instagram.android" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="alex.r" resource-id="com.instagram.android:id/header_title" class="android.widget.TextView" package="com.instagram.android" content-desc="" bounds="[220,110][460,170]" />
    <node index="1" text="" resource-id="com.instagram.android:id/row_thread_composer_edittext" class="android.widget.EditText" package="com.instagram.android" content-desc="" bounds="[160,2250][860,2330]" />
  </node>
</hierarchy>
```

- [ ] **Step 2: Write the failing tests**

`app/src/test/java/com/jev/probe/capture/InstagramParseTest.kt`:

```kotlin
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.InstagramParseTest'`
Expected: compilation FAILS, `Unresolved reference: parseInstagram`.

- [ ] **Step 4: Implement**

`app/src/main/java/com/jev/probe/capture/InstagramAdapter.kt`:

```kotlin
package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * Instagram Direct (com.instagram.android). Ids verified against the dumps in
 * src/test/resources/dumps (see its README for app version and device).
 *
 * "In a thread" = the thread composer exists. The inbox has a search EditText
 * but never this id, so it returns null. Message bodies are TextViews with
 * [IG_BODY_ID]; side comes from which screen edge the bubble hugs.
 */
class InstagramAdapter : ChatAppAdapter {
    override val pkg = "com.instagram.android"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseInstagram(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseInstagram(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id == IG_COMPOSER_ID }) return null
    val bodies = nodes.filter { it.id == IG_BODY_ID && it.text.isNotBlank() }.sortedBy { it.top }
    val title = nodes.firstOrNull { it.id == IG_TITLE_ID && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { Msg(sideByEdges(it.left, it.right, width), it.text.trim()) })
}

private const val IG_BODY_ID = "com.instagram.android:id/direct_text_message_text_view"
private const val IG_COMPOSER_ID = "com.instagram.android:id/row_thread_composer_edittext"
private const val IG_TITLE_ID = "com.instagram.android:id/header_title"
```

If Task 7 found the bodies in `content-desc`, change `it.text` to `it.desc` in the two body expressions and adjust the fixture to match.

- [ ] **Step 5: Run to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.InstagramParseTest'`
Expected: 3 passed.

- [ ] **Step 6: Add the real-dump regression test**

Append to `InstagramParseTest`, filling the expected list from `dumps/README.md` (Task 7 Step 4) with the real screen width:

```kotlin
    @Test fun realThreadDump() {
        val s = parseInstagram(DumpXml.load("instagram_thread_real.xml"), 1200)!!
        assertEquals(listOf(
            Msg("other", "<first visible message from README>"),
            Msg("me", "<second from README>")
            // ... every message listed in dumps/README.md, in order
        ), s.messages)
    }

    @Test fun realInboxDump() {
        assertNull(parseInstagram(DumpXml.load("instagram_inbox_real.xml"), 1200))
    }
```

(Replace each `<...>` with the literal text from the README. The README is the source of truth for what was on screen.)

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.InstagramParseTest'`
Expected: 5 passed. If `realThreadDump` fails, fix the constants or the side rule, not the test.

- [ ] **Step 7: Register the adapter**

`ChatCaptureService.kt:46`:

```kotlin
    private val adapters = listOf(
        WeChatAdapter(), QQAdapter(), XAdapter(), FeishuAdapter(), InstagramAdapter()
    ).associateBy { it.pkg }
```

Run: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add app/src
git commit -m "feat: read Instagram Direct threads automatically"
```

---

### Task 9: Google Messages (SMS) adapter

**Files:**
- Create: `app/src/main/java/com/jev/probe/capture/MessagesAdapter.kt`
- Create: `app/src/test/java/com/jev/probe/capture/MessagesParseTest.kt`
- Create: `app/src/test/resources/dumps/messages_thread.xml`, `messages_list.xml`
- Modify: `app/src/main/java/com/jev/probe/capture/ChatCaptureService.kt:46`

**Interfaces:**
- Consumes: `NodeLite`, `flatten`, `sideByEdges`, `topTitle` (Task 2).
- Produces: `class MessagesAdapter : ChatAppAdapter` with `pkg = "com.google.android.apps.messaging"`; `internal fun parseMessages(nodes: List<NodeLite>, width: Int): ChatSnapshot?`.

Google Messages ids have changed across versions, so match by **suffix** (`:id/message_text`), the same approach `FeishuAdapter` uses. Confirm the ids against Task 7's table.

- [ ] **Step 1: Hand-written fixtures** (width 1080)

`messages_thread.xml`:

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.google.android.apps.messaging" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="Mom" resource-id="com.google.android.apps.messaging:id/conversation_title" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[200,110][400,170]" />
    <node index="1" text="Did you land?" resource-id="com.google.android.apps.messaging:id/message_text" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[60,500][520,570]" />
    <node index="2" text="9:41 AM" resource-id="com.google.android.apps.messaging:id/message_status" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[60,575][240,610]" />
    <node index="3" text="Just now, waiting for bags" resource-id="com.google.android.apps.messaging:id/message_text" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[480,660][1030,730]" />
    <node index="4" text="Call me when you're out" resource-id="com.google.android.apps.messaging:id/message_text" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[60,820][640,890]" />
    <node index="5" text="" resource-id="com.google.android.apps.messaging:id/compose_message_text" class="android.widget.EditText" package="com.google.android.apps.messaging" content-desc="" bounds="[150,2250][880,2330]" />
  </node>
</hierarchy>
```

`messages_list.xml`:

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="com.google.android.apps.messaging" content-desc="" bounds="[0,0][1080,2400]">
    <node index="0" text="Messages" resource-id="" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[60,110][400,170]" />
    <node index="1" text="Mom" resource-id="com.google.android.apps.messaging:id/conversation_name" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[200,300][400,350]" />
    <node index="2" text="Call me when you're out" resource-id="com.google.android.apps.messaging:id/conversation_snippet" class="android.widget.TextView" package="com.google.android.apps.messaging" content-desc="" bounds="[200,360][900,410]" />
  </node>
</hierarchy>
```

- [ ] **Step 2: Write the failing tests**

`app/src/test/java/com/jev/probe/capture/MessagesParseTest.kt`:

```kotlin
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.MessagesParseTest'`
Expected: compilation FAILS, `Unresolved reference: parseMessages`.

- [ ] **Step 4: Implement**

`app/src/main/java/com/jev/probe/capture/MessagesAdapter.kt`:

```kotlin
package com.jev.probe.capture

import android.content.res.Resources
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * Google Messages (SMS/RCS, com.google.android.apps.messaging). Ids verified
 * against src/test/resources/dumps (see its README). Matched by suffix because
 * the package prefix of ids has moved between app versions.
 *
 * "In a conversation" = the compose box exists; the conversation list has none.
 * Bodies carry `:id/message_text`, so timestamps/status lines are excluded by id.
 * Side comes from which screen edge the bubble hugs.
 */
class MessagesAdapter : ChatAppAdapter {
    override val pkg = "com.google.android.apps.messaging"

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? =
        parseMessages(flatten(root), res.displayMetrics.widthPixels)
}

internal fun parseMessages(nodes: List<NodeLite>, width: Int): ChatSnapshot? {
    if (nodes.none { it.id.endsWith(SMS_COMPOSER) }) return null
    val bodies = nodes.filter { it.id.endsWith(SMS_BODY) && it.text.isNotBlank() }.sortedBy { it.top }
    val title = nodes.firstOrNull { it.id.endsWith(SMS_TITLE) && it.text.isNotBlank() }?.text?.trim()
        ?: topTitle(nodes, bodies.firstOrNull()?.top ?: Int.MAX_VALUE)
    return ChatSnapshot(title, bodies.map { Msg(sideByEdges(it.left, it.right, width), it.text.trim()) })
}

private const val SMS_BODY = ":id/message_text"
private const val SMS_COMPOSER = ":id/compose_message_text"
private const val SMS_TITLE = ":id/conversation_title"
```

- [ ] **Step 5: Run to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.MessagesParseTest'`
Expected: 2 passed.

- [ ] **Step 6: Real-dump regression tests**

Append to `MessagesParseTest`, with the expected list copied from `dumps/README.md`:

```kotlin
    @Test fun realConversationDump() {
        val s = parseMessages(DumpXml.load("messages_thread_real.xml"), 1200)!!
        assertEquals(listOf(
            Msg("other", "<first visible message from README>"),
            Msg("me", "<second from README>")
            // ... every message listed in dumps/README.md, in order
        ), s.messages)
    }

    @Test fun realListDump() {
        assertNull(parseMessages(DumpXml.load("messages_list_real.xml"), 1200))
    }
```

Run: `./gradlew :app:testDebugUnitTest --tests 'com.jev.probe.capture.MessagesParseTest'`
Expected: 4 passed.

- [ ] **Step 7: Register the adapter**

```kotlin
    private val adapters = listOf(
        WeChatAdapter(), QQAdapter(), XAdapter(), FeishuAdapter(), InstagramAdapter(), MessagesAdapter()
    ).associateBy { it.pkg }
```

Run: `./gradlew :app:testDebugUnitTest :app:assembleDebug && python3 tools/check_cjk.py`
Expected: `BUILD SUCCESSFUL`, `0 line(s) with Chinese text`.

- [ ] **Step 8: Commit**

```bash
git add app/src
git commit -m "feat: read Google Messages (SMS) conversations automatically"
```

---

### Task 10: On-device acceptance (HUMAN + agent)

**Files:**
- Modify: `docs/acceptance.md` (append an "Instagram & SMS" section with the results)
- Modify: `CHANGELOG.md` (new top entry)
- Modify: `app/build.gradle.kts` (`versionCode = 5`, `versionName = "1.4"`)

- [ ] **Step 1: Build and install**

```bash
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

After installing, turn the Jev accessibility service **off and on again** (the upstream note: screenshot capability only takes effect after a re-enable).

- [ ] **Step 2: Run the checklist and record actual results in `docs/acceptance.md`**

| # | Check | Pass when |
|---|---|---|
| 1 | Main screen, settings, knowledge screen, overlay, bubble menu, notification | No Chinese anywhere |
| 2 | Instagram: open a thread, have the other person send "are you free tomorrow?" | Bubble auto-analyzes; 3 English candidates; judgment shown |
| 3 | Instagram: tap Fill on a candidate | Text lands in the composer; **nothing is sent**; toast "Filled in. Review it, then send it yourself" |
| 4 | Instagram inbox (not a thread) | No analysis runs |
| 5 | Google Messages: repeat 2–4 in an SMS conversation | Same outcomes |
| 6 | A Chinese-language WeChat or QQ chat | Still captured; candidates come back in Chinese |
| 7 | X DM in English UI (`You: …`) | Sides correct |
| 8 | `adb logcat -s JEVASSIST` during 2 and 5 | Only counts/lengths logged, never message text |

Write down the actual outcome for every row. If something failed, say what you saw. Don't mark a row as passing without doing it.

- [ ] **Step 3: Version + changelog**

`app/build.gradle.kts`: `versionCode = 5`, `versionName = "1.4"`. At the top of `CHANGELOG.md`:

```markdown
## 1.4 — 2026-09-22
- English UI, prompts and docs. Replies follow the language of the conversation.
- New: Instagram Direct and Google Messages (SMS) are read automatically.
- English timestamps and read receipts ("9:41 AM", "Seen", "Yesterday") are ignored in capture and OCR.
```

- [ ] **Step 4: Final check and commit**

Run: `./gradlew :app:testDebugUnitTest :app:assembleDebug && python3 tools/check_cjk.py`
Expected: all green, `0 line(s)`.

```bash
git add docs/acceptance.md CHANGELOG.md app/build.gradle.kts
git commit -m "release: v1.4 English + Instagram + SMS"
```

Don't push. The owner decides.

---

## Out of scope (add when needed)

- **Samsung Messages** (`com.samsung.android.messaging`) and **Xiaomi Messages** (`com.android.mms`): each would be a copy of Task 9 with its own dump. Add one when a user's phone uses it. Until then, the bubble menu's "Read screen once (OCR)" works there.
- **Switching OCR to ML Kit's Latin model:** the bundled Chinese model already reads Latin text, and WeChat users still need Chinese.
- **Moving strings to `strings.xml` / Android localization:** the codebase builds its UI in code with inline strings. Translating in place is the shortest change. Add resource-based i18n if a second UI language is ever wanted.
