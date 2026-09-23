# Acceptance criteria (the shared ruler)

All tasks are judged against this. **Builders don't self-certify — paste real output.**

## A. Build

```
H:\ai_tool\jev-android\gradlew.bat assembleDebug
```
Zero errors. Output artifact `app/build/outputs/apk/debug/app-debug.apk` exists.

## B. Probe gate (P1, decides which route the whole project takes)

Install the probe app, enable the accessibility service, leave the phone sitting on **an open WhatsApp, Instagram, or Messages thread**, then:

```
adb shell am broadcast -a com.jev.probe.DUMP
adb shell run-as com.jev.probe ls -l files/
```

Verdict:
- **PASS-A**: the dump file contains chat bubble text (you can see message content and `android.widget.TextView` nodes), and node count > 20. → take route A (real-time accessibility text)
- **FAIL**: only an empty root node, or node count ≤ 3. → take route B (screenshot + local OCR)

Also verify that `takeScreenshot()` can capture a bitmap of the open chat UI (saved as PNG, not all black).

## C. Jev judgment layer

```
python tools/jev/calibrate.py
```
Outputs a per-question hit-rate table against the labeled set, plus a confidence distribution. Requirements:
- The labeled set has at least 20 conversation snippets
- `danger_level` scoring has a mean absolute error < 1.0 grade versus human labels
- `true_intent` / `she_needs` hit rate ≥ 60%
- All requests return HTTP 200, and no key leaks to stdout

## D. Real-device smoke test (final verification, run only once)

1. Within **1.5 seconds** of the other person sending a new message, the overlay shows an analysis with at least 3 ranked reply candidates
2. Tapping "Fill" makes text appear in the chat input box, **and it is not sent**
3. Messages you send yourself don't trigger analysis; switching chats resets context; the overlay hides when the chat app goes to the background
4. The key never appears in logcat; on a dropped connection, it shows a readable error without crashing
5. Zero Jev calls during a 10-minute idle period

## v1.4 — Instagram & SMS (2026-09-22)

| # | Check | Pass when | Result |
|---|---|---|---|
| 1 | Main screen, settings, knowledge screen, overlay, bubble menu, notification | No Chinese anywhere | NOT RUN — needs owner (no device connected) |
| 2 | Instagram: open a thread, have the other person send "are you free tomorrow?" | Bubble auto-analyzes; 3 English candidates; judgment shown | NOT RUN — needs owner (no device connected) |
| 3 | Instagram: tap Fill on a candidate | Text lands in the composer; **nothing is sent**; toast "Filled in. Review it, then send it yourself" | NOT RUN — needs owner (no device connected) |
| 4 | Instagram inbox (not a thread) | No analysis runs | NOT RUN — needs owner (no device connected) |
| 5 | Google Messages: repeat 2–4 in an SMS conversation | Same outcomes | NOT RUN — needs owner (no device connected) |
| 6 | A Chinese-language QQ chat | Still captured; candidates come back in Chinese | NOT RUN — needs owner (no device connected) |
| 7 | X DM in English UI (`You: …`) | Sides correct | NOT RUN — needs owner (no device connected) |
| 8 | `adb logcat -s JEVASSIST` during 2 and 5 | Only counts/lengths logged, never message text | NOT RUN — needs owner (no device connected) |

### Automated checks run
- Unit tests: `./gradlew :app:testDebugUnitTest` — 16 tests passed, 0 failures
- Build: `./gradlew :app:assembleDebug` — successful, APK size 28 MB, path: `/Users/andy/Jev Chat/jev-chat-jarvis/app/build/outputs/apk/debug/app-debug.apk`
- CJK check: `python3 tools/check_cjk.py` — 0 line(s) with Chinese text

Before running rows 2–5, capture real dumps per app/src/test/resources/dumps/README.md.

## v1.4 — Chrome extension (2026-09-22)

| # | Check | Pass when | Result |
|---|---|---|---|
| 1 | Instagram web: test thread, other side sends "are you free tomorrow?" | Panel shows intent, risk and 3 ranked English replies within ~5 s | NOT RUN — needs owner (load unpacked in Chrome) |
| 2 | Fill on Instagram | Text appears in the message box; **nothing is sent**; typing afterwards still works (the editor didn't break) | NOT RUN — needs owner (load unpacked in Chrome) |
| 3 | Instagram inbox / feed | Panel doesn't analyze | NOT RUN — needs owner (load unpacked in Chrome) |
| 4 | Google Messages web: repeat 1–3 | Same outcomes | NOT RUN — needs owner (load unpacked in Chrome) |
| 5 | Wrong key | Panel shows "Something went wrong" + `HTTP 401: …`; no crash | NOT RUN — needs owner (load unpacked in Chrome) |
| 6 | DevTools console on both sites + service worker console | No message text logged | NOT RUN — needs owner (load unpacked in Chrome) |

### Automated checks run
- Unit tests: `cd extension && npm test` — 15 tests passed, 0 failures
- `node --check background.js` — exit 0
- `node --check content.js` — exit 0 (also checked with `node --check --input-type=commonjs < content.js` — exit 0; content.js is a classic script with no top-level import/export, so plain `--check` also succeeds)
- `node --check panel.js` — exit 0
- `node --check options.js` — exit 0
- `node --check lib/api.js` — exit 0
- Reference check (one-off script, not committed): every file `manifest.json` points to (`background.service_worker`, `side_panel.default_path`, `options_page`, `content_scripts[].js`, `web_accessible_resources[].resources` globs) and every `src=` in `panel.html` / `options.html` exists on disk — all resolved, none missing
- `python3 tools/sync_brain.py --check` — exit 0
- `python3 tools/check_cjk.py` — `0 line(s) with Chinese text`

Before running rows 1–4, confirm the selectors in `extension/test/fixtures/README.md` still match the live Instagram/Google Messages DOM — they were written against hand-built fixtures, not yet captured from the real sites.

## v1.4 — Mac (Apple Messages) live AX dumps (2026-09-22)

Live capture steps from the Mac plan Task 3. `--dump` / Accessibility / Messages were not run in this checkout; hand-written fixtures only. See `mac/Fixtures/README.md`.

| # | Check | Pass when | Result |
|---|---|---|---|
| 1 | Grant Accessibility to the terminal (or host app) running `JevMac` | System Settings → Privacy & Security → Accessibility lists that app | NOT RUN — needs owner |
| 2 | Messages open on a test conversation; `swift run JevMac --dump Fixtures/messages_window_real.json` | `wrote … (N elements)` with N in the hundreds; JSON scrubbed of real names/numbers | NOT RUN — needs owner |
| 3 | No conversation selected (or empty compose window); dump `messages_no_convo_real.json` | Same N-scale write; parser would return nil | NOT RUN — needs owner |
| 4 | Walk the window dump for roles (sidebar search, transcript bubbles, header, composer) | Matches expected roles in `mac/Fixtures/README.md`, or parser/fixtures updated to match live | NOT RUN — needs owner |
| 5 | JevChecks against the real dump files | Title/messages/no-convo checks pass | NOT RUN — needs owner |

## v1.4 — Mac app (2026-09-22)

Live menu-bar acceptance from the Mac plan Task 5. Accessibility was not granted in this checkout; do not run these rows without the owner.

| # | Check | Pass when | Result |
|---|---|---|---|
| 1 | Messages frontmost, test conversation, the other side sends "are you free tomorrow?" | Panel shows intent, risk and 3 ranked replies within ~5 s | NOT RUN — needs owner |
| 2 | Fill | Text appears in the compose field; **nothing is sent** | NOT RUN — needs owner |
| 3 | Fill when the field can't be set (e.g. Messages minimized) | Panel says "Copied. Click the message box and press ⌘V."; the clipboard holds the reply | NOT RUN — needs owner |
| 4 | Switch to another app | Polling stops (no new panel updates) | NOT RUN — needs owner |
| 5 | Console.app filtered on "jev" | Only timing lines; no message text | NOT RUN — needs owner |
| 6 | Slow-tick lines | None, or under 300 ms typical. If ticks are often slow, record it: the upgrade is AXObserver (see the `ponytail:` note) | NOT RUN — needs owner |
| 7 | Quit from the menu, relaunch | Keys persist (Keychain); relationship persists | NOT RUN — needs owner |

## v1.4 — WhatsApp and Snapchat (2026-09-22)

Ids and selectors are expected values from hand-written fixtures. Confirm them on a device before relying on a live chat.

| # | Check | Pass when | Result |
|---|---|---|---|
| 1 | Android WhatsApp thread | Panel shows the open chat; chat list does not analyze | NOT RUN — needs owner |
| 2 | Android Snapchat thread | Panel shows the open chat; friend list does not analyze | NOT RUN — needs owner |
| 3 | Chrome on macOS or Windows: web.whatsapp.com thread | Side panel shows the thread; chat list does not | NOT RUN — needs owner |
| 4 | Chrome: web.snapchat.com thread | Side panel shows the thread | NOT RUN — needs owner |
| 5 | Mac WhatsApp Desktop, iPhone linked | Menu-bar panel reads the open chat; Fill does not send | NOT RUN — needs owner |
