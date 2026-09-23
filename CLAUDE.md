# Jev Chat Assistant (Android) — cross-app non-invasive conversation copilot

A non-invasive assistant that sits alongside chat apps (WhatsApp, Snapchat, Instagram, Messages, and others): reads the other person's latest message → calls Jev to judge it → the overlay shows the analysis and 3 ranked reply candidates (ranked by Jev) → the person taps once to fill it into the input box. **Sending is always a manual tap by the person; the program never sends automatically.**

## Hard constraints (everyone must follow)

1. **No hooking, no Xposed, no modifying the target app, no reading its database.** Only the system accessibility service and screenshots are used.
2. **Never auto-send a message**, and never tap the target app's send button. Stop once the text is filled into the input box.
3. **Never touch money**: don't touch any UI element related to transfers, red packets, or payment QR codes.
4. **All paths must be ASCII**: the Android build tools reject non-ASCII paths on Windows. The project must live at `H:\ai_tool\jev-android`.
5. **Keys never hit disk, logs, or git**: the OpenRouter key is read from the `OPENROUTER_API_KEY` environment variable, or from an encrypted setting in the app. No file may ever contain a string starting with `sk-or-`.
6. Encoding is always UTF-8. On Windows with a Chinese locale, use PowerShell pwsh 7+; Python file I/O must explicitly pass `encoding='utf-8'`.
7. `git commit` / `git push` are forbidden; a human decides.

## Tech stack

- Kotlin, classic View + XML, **no Compose**
- minSdk 30, compileSdk / targetSdk 35
- JDK 17 (`H:\android\jdk`), Android SDK at `H:\android\sdk`, Gradle cache at `H:\android\gradle-home`
- Target device: Xiaomi 14 (houji / 23127PN0CC), HyperOS 3.0 / Android 16 (SDK 36)
- Model clients are split three ways: `jev/JudgeClient` (judgment), `jev/ReplyClient` (reply drafting), `jev/VisionClient` (vision, for OCR), sharing `jev/HttpJson`; configuration lives in `core/Prefs` (`judge*` / `reply*` / `vision*` fields), with a one-time migration of the old key gated by the flag `prefs_migrated_v13`.
- ML Kit `com.google.mlkit:text-recognition-chinese:16.0.1` (the bundled variant, not the play-services one); `ndk.abiFilters` keeps only `arm64-v8a`.

## Key background (verified on real hardware 2026-09-21, don't relearn these the hard way)

- The accessibility service is registered as `com.google.android.accessibility.selecttospeak.SelectToSpeakService` in the Manifest — do not rename that class or entry.
- Fallback route: the accessibility service's `takeScreenshot()` + local OCR (ML Kit), which also costs zero tokens.
- Feishu Android (verified on real hardware 2026-09-21): message bodies are custom-drawn, so **there's no text in the accessibility tree** (the disguised service sees the same thing as `uiautomator dump`) — only the `bubble_content_container` bubble position, the `group_name` title, and the `kb_rich_text_content` input box are visible; message bodies have to go through takeScreenshot + OCR. Feishu's default layout is left-aligned, so me/them can't be told apart by left/right position.
- Mobile QQ 9.3.50 (verified on real hardware 2026-09-21, Xiaomi 14 / 1200×2670): nodes are **not obfuscated**; a plain `uiautomator dump` can read them. Message body is `com.tencent.mobileqq:id/mjn` (a TextView whose text is the message body), group nickname is `id/mjq`, title is `id/371`, input box is `id/input`, send button is `id/send_btn` (**never call performAction on it**). Timestamps and system notice bars have no id, so filtering for just `id/mjn` naturally excludes them.
- QQ runs entirely inside `SplashActivity` (a fragment-based architecture), so **you can't tell whether you're in a chat window by activity name** — you can only check whether the tree has `id/mjn` / `id/input`. Avatars sit outside their own bubble (the other person's avatar has left≈width×0.13, mine has right≈width−width×0.13); to decide me/them, compare distance to the left vs. right avatar column, not the bubble's center point (a long message's center can cross past halfway across the screen).
- X / Twitter 12.25.2 (verified on real hardware 2026-09-21, Xiaomi 14 / 1200×2670 / Chinese UI language): the DM screen is **Compose UI, message nodes have no resource-id** — they're `android.view.View`, full-width `[0,y][1200,y+h]`, with empty `text`, and **everything is in content-desc**, in the format `Sender：Body text。8:11 AM。Read。` (full-width colon as separator, `。` glues fields together, may end with a time and `Read`). An attachment row like `All-In：attached post。。` nests a TextView quoting the referenced post inside it — only read the desc of the View itself, not its children.
- X **every screen is `com.x.android.main.MainActivity`, so activity name can't tell you the screen**: the conversation screen has an EditText (the only one, `[204,2424][1152,2568]`), the DM list screen doesn't → decide by "does the tree have an editable node." List-screen rows look similar too (full-width View + desc), but their format is `All-In, @all_in_2026, body text…` — filter those out again by checking for `, @`. The send button only appears after typing something, **never tap it**.
- Instagram (`com.instagram.android`) and Google Messages (`com.google.android.apps.messaging`) adapters are `capture/InstagramAdapter.kt` and `capture/MessagesAdapter.kt`; their parsers are pure functions over `NodeLite`, tested against fixtures in `app/src/test/resources/dumps/` (see its README).
- The capture layer dispatches by app: `capture/ChatAppAdapter.kt` has one adapter per app, `ChatCaptureService` looks one up by the foreground package name; everything downstream is generic.
- Jev = TypeSafe's judgment model. It only answers multiple-choice / scoring / yes-no questions, it doesn't generate free text. It runs over OpenRouter:
  `POST https://openrouter.ai/api/alpha/decisions`, model `typesafe/jev-1.13`,
  body `{model, state, questions}`, answers come back in `answers`. Measured: about 900 ms and ~1000 input tokens per call for 7 questions, roughly $0.00004.
- Jev's primary training language is English: **write question instructions and criteria in English; keep the chat content inside `state` in its original language.**
- Knowledge-base / context data lives as JSON files under `filesDir/kb` (`notes.json` / `contacts.json` / `logs/<contactId>.json`); `KbStore` uses a single lock + atomic writes (write to `.tmp` then rename). `ContextBuilder` only does "always-on notes included in full" + tag/title substring matching (no semantic retrieval, no scoring); **it never auto-creates a contact record, and history is off by default (`contextEnabled=false`)**.
- A Kotlin string template `$x` immediately followed by certain punctuation (e.g. `」`, `）`) gets parsed as part of the identifier, causing an `Unresolved reference` compile error; **always write `${x}` instead**. Hit this during phase D in `KbStore.kt` / `KbSelfCheck.kt`.
- The OCR layer lives in `capture/ocr`: `ScreenCapture` rate-limits to ≥1s between shots plus failure backoff (1s→2s→4s→8s→16s→30s cap), with a human-readable message for each of error codes 1/2/3/4/6; `MlKitOcr` uses the bundled Chinese model. Adapter contract: `extract` returning `null` means "not in a chat window"; returning an empty message list means "in a chat window but the tree has no message text" — only the latter triggers the OCR fallback.
- The accessibility XML now has `android:canTakeScreenshot="true"` added; **after changing it, accessibility must be turned off and back on for it to take effect**, otherwise `takeScreenshot` immediately returns errorCode 2. Whether the disguised service (`SelectToSpeakService`) can screenshot on HyperOS is unverified; if it's refused (code 1/2, still refused after re-enabling accessibility), stand up a separate, non-disguised, screenshot-only service — `ScreenCapture` is already wrapped so its host service can be swapped.

## macOS toolchain setup

- `brew install openjdk@17` and `brew install --cask android-commandlinetools`; then `sdkmanager "platforms;android-35" "build-tools;35.0.0" "platform-tools"`; create `local.properties` with `sdk.dir=/opt/homebrew/share/android-commandlinetools`.
- Environment needed for every Gradle run:
  - `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
  - `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`
  - `JEV_KEYSTORE_PROPS=/nonexistent/jev-release.properties` (needed on macOS: `app/build.gradle.kts` defaults this to a Windows `H:/` path, which makes Gradle's `file()` throw. Point it at a real properties file to sign release builds.)
- Unit tests: `./gradlew :app:testDebugUnitTest`
- CJK check: `python3 tools/check_cjk.py`

Note for Windows builders (original paths, kept for reference): JDK 17 at `H:\android\jdk`, Android SDK at `H:\android\sdk`, Gradle cache at `H:\android\gradle-home`, project root at `H:\ai_tool\jev-android` (see hard constraint 4 above — paths must be ASCII).

## Directories and file ownership

| Directory | Owner | Notes |
|---|---|---|
| `app/`, `gradle/`, root gradle files | Android build owner | The Android project |
| `tools/jev/` | Jev judgment owner | Python question sets and calibration scaffolding, run on a PC |
| `docs/` | Controller | Acceptance criteria, reports |
| `docs/v1.3-plan.md` | Controller | The v1.3 master plan and revisions, **required reading for every worker** |
| `_reports/` | Everyone | Every task's delivery report goes here |

Cross-boundary issues are **reported only, never fixed directly** — the controller resolves them.

## Report format

After finishing a task, write `_reports/<task-name>_report.md`: root cause or approach (with evidence) → what changed (file by file) → the **actual output** of the acceptance commands (paste verbatim, never fabricated) → **self-verification gaps** (say plainly what wasn't verified).
