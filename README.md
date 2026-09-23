<div align="center">

<img src="docs/images/logo.png" width="150" alt="Jev Chat Assistant" />

# Jev Chat Assistant

**A conversation copilot: in WhatsApp, Snapchat, Instagram, and SMS it reads the other person, suggests replies, and fills the input box in one tap. Whether to send is up to you. Non-invasive: it only reads the screen, with no hooking and no app modification.**

</div>

## Why use it

- **It judges before it writes.** Most tools just let a model make up a reply on the spot. Jev first uses a judgment model to work out the other person's real intent, the risk level, and whether to reply right now — then drafts a reply based on that.
- **It doesn't touch your chat app.** No hooking, no repackaging, no calling any app's private API or accessing its account system, no reading its database — it only uses the system accessibility service (or a browser content script) to read the conversation currently on screen.
- **The send button is always yours.** The program only fills a reply into the input box; it never sends automatically.
- **One core, many platforms.** WhatsApp, Snapchat, Instagram, and SMS/RCS work on Android; the Chrome/Firefox extension covers the same sites on a laptop; the Mac menu-bar app covers Apple Messages and WhatsApp Desktop.
- **It knows your people and your context.** A local knowledge base and contact profiles are automatically pulled in during analysis — matching notes and that person's history — so replies won't contradict what you've told it.
- **You configure the endpoints.** Judge / reply / vision are each configurable separately, using your own key and quota, with no middle server in between.
- **Privacy stays on-device.** Keys are stored in the app's private storage; chat content is only sent to your configured endpoint at the moment you trigger an analysis — nothing is written to disk or logged.

## Supported apps

| App | Status | Capture method | Notes |
|---|---|---|---|
| WhatsApp Android | ✅ full pipeline | Accessibility node reading | Expected view ids, not yet verified on a device. Business app (`com.whatsapp.w4b`) uses the same reader |
| Snapchat Android | ✅ full pipeline | Accessibility node reading | Expected view ids, not yet verified on a device |
| Instagram | ✅ full pipeline | Accessibility node reading | DMs, real device |
| Google Messages (SMS/RCS) | ✅ full pipeline | Accessibility node reading | SMS/RCS threads, real device |
| QQ Android | ✅ full pipeline | Accessibility node reading | Verified on 9.3.50 (group chat) on real hardware |
| X / Twitter DMs | ✅ full pipeline | Parses Compose nodes' content-desc | Verified on 12.25 |
| Feishu / Lark | ✅ OCR fallback | Accessibility bubble rectangles + ML Kit offline OCR | Message body is custom-drawn |
| Any other app | ✅ manual | Overlay menu "Read screen once (OCR)" | Not automatic; does not distinguish me/them |
| Desktop / web | ✅ Chrome & Firefox extension + Mac menu bar | DOM / Accessibility | See sections below |

This project only reads chats on your own device that you already have the right to view.

## Quick start

**1. Install the app.** The repo ships a signed release build: [`apk/jev-assistant-v1.3-release.apk`](apk/jev-assistant-v1.3-release.apk) (Android 11+).

```bash
adb install -r apk/jev-assistant-v1.3-release.apk
```

**2. Enter your key.** Open the app → Settings → "Endpoints" has three cards: Judge API / Reply API / Vision API. The simplest setup is to fill in just the "Judge API" card with your [OpenRouter](https://openrouter.ai/) API key — leave the other two blank and they'll automatically inherit this key.

**3. Grant permissions.** Follow the home-screen wizard:

- Accessibility (to read messages; after upgrading you may need to turn it off and back on once)
- Display over other apps / overlay window (to show the analysis)
- Autostart + no battery restrictions on skins that freeze background processes

If you had a debug build installed, uninstall it before installing the release build (different signatures); uninstalling clears your key and settings.

## Laptop (Chrome or Firefox)

The same extension gives the judge-then-draft pipeline on a laptop, in Chrome's side panel or Firefox's sidebar.

**Chrome.** `chrome://extensions` → enable Developer mode → **Load unpacked** → select the `extension/` folder in this repo.

**Firefox.** `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on…** → pick `extension/manifest.json`. Temporary add-ons disappear when Firefox quits; load that file again after a restart.

**Key setup.** Right-click the toolbar icon → Options (Firefox: Extensions → Jev Assistant → Options) → paste your [OpenRouter](https://openrouter.ai/) API key into "Judge API key" and save. Leave "Reply API key" blank to reuse the Judge key, or set your own relationship note and models under Advanced.

**Supported sites:** WhatsApp Web (`web.whatsapp.com`), Snapchat Web (`web.snapchat.com`), Instagram web (`instagram.com`, Direct threads), and Google Messages for web (`messages.google.com`). Click the toolbar icon to open the panel while one of those sites is the active tab.

**iPhone chats on a computer.** An iPhone app cannot read WhatsApp or Snapchat. Link the iPhone in WhatsApp (WhatsApp Desktop on the Mac, or WhatsApp Web), or open Snapchat Web in Chrome or Firefox while signed in. Jev reads that window.

**It never sends.** Clicking "Fill" on a suggested reply only puts the text into that site's own message box — it never presses Enter and never clicks a send button. You always review and send it yourself.

Selectors are written against hand-built fixtures and haven't yet been confirmed against every live DOM — see `extension/test/fixtures/README.md` before relying on this in a real conversation.

## Mac (Apple Messages and WhatsApp Desktop)

A menu-bar app for Apple Messages (iMessage and SMS forwarded from an iPhone) and for WhatsApp Desktop (chats linked from an iPhone). Snapchat on a computer is the browser extension, because Snapchat has no Mac app.

**Requirements.** macOS 14+, Messages signed in, and iPhone SMS forwarding on if you want SMS threads.

**Build.** From the repo root:

```bash
bash mac/package.sh
```

That produces `mac/build/Jev Assistant.app` (ad-hoc signed). Open it; a **Jev** item appears in the menu bar.

**Permissions.** Grant Accessibility when prompted (System Settings → Privacy & Security → Accessibility). Use the Jev menu to set the Judge API key (and optionally a Reply key / relationship note). Ad-hoc signatures change every rebuild, so macOS may ask for Accessibility again after you rebuild.

**It never sends.** Fill only sets the compose field value (or copies to the clipboard if the field can't be set). It never presses Return, never clicks Send, and never uses AppleScript to send.

## Features

### Judgment and reply candidates

- The judgment model returns, in one call: the other person's real intent, risk level (1–9), what they want, whether to reply right away, and the best action to take. About 1 second, with a confidence score attached.
- The generation model drafts 3 casual, natural-sounding candidates; the judgment model ranks them by "best fit" and gives a share for each.
- Tap once in the overlay to copy or fill in — filling uses `ACTION_SET_TEXT`, falling back automatically to clipboard-paste on failure. **It never sends, under any circumstances.**

### Knowledge base and contacts

Under Settings → Analysis → "Knowledge base & contacts."

- **Notes**: title / content / tags / always-on.
- **Contacts**: name / aliases / relationship / notes.
- **History**: off by default; when enabled, each analysis can include recent local history.
- **Clear**: both live in the app's private directory; settings can wipe them in one tap.

### Endpoints and models

- The address, key, and model for judge / reply / vision can each be set independently.
- Works with just one key: leaving reply and vision blank makes them inherit the judge endpoint's configuration.

### Capture and OCR

- One adapter per app; the service dispatches by foreground package name.
- When the accessibility tree has no message text, it can take a screenshot and run offline OCR — no image is uploaded.
- Any app can trigger "Read screen once (OCR)" manually from the overlay menu.

## FAQ

<details>
<summary><b>Will it send messages for me?</b></summary>

No. The program only fills the selected reply into the input box — you always tap send yourself.

</details>

<details>
<summary><b>Does it need root or Xposed? Will it get my account banned?</b></summary>

No root needed, and no modules to install. It doesn't modify the chat app's package, doesn't inject into its process, doesn't call any private API — it only reads what the system accessibility service (or the page DOM) exposes.

</details>

<details>
<summary><b>Will my chat history get uploaded?</b></summary>

Chat content is only sent, at the moment you trigger an analysis, to the model endpoint you yourself configured in settings. This project runs no server of its own — nothing is collected, written to disk, or logged. History is off by default; once enabled, it's still only stored in the app's private directory on your phone.

</details>

<details>
<summary><b>Does it cost money?</b></summary>

The app itself is free and open source. Model calls go through your own API key and are billed by the provider based on usage — the project never handles any money.

</details>

## How it works

```
WhatsApp / Snapchat / Instagram / Messages ──(accessibility / DOM)──▶ capture recent messages
                                  │
              ┌───────────────────┴───────────────────┐
              ▼                                        ▼
   Jev judgment (7 questions, one call)      generation model drafts 3 candidates
   intent / risk / needs / action / reply-now?          │
              └───────────────────┬───────────────────┘
                                  ▼
                        Jev ranks the 3 candidates
                                  ▼
              overlay / side panel shows results → copy / fill (never sends)
```

- **Capture**: one adapter per app (or site), dispatched by package name or host. An adapter's only job is turning the current window into "title + message list (who said what)" — everything downstream is generic.
- **Judgment**: [Jev](https://docs.typesafe.ai/) only answers multiple-choice / scoring / yes-no questions, all in one request.
- **Reply**: the generation model drafts 3 candidates, Jev ranks them.
- **Fill-in**: set the compose field (or clipboard paste) — never sends.

<details>
<summary><b>Adapting a new chat app</b></summary>

1. Implement `ChatAppAdapter` in `capture/ChatAppAdapter.kt`: `pkg` is the package name, `extract(root, res)` pulls the title and message list.
2. Add a line to `adapters` in `capture/ChatCaptureService.kt`.
3. Judgment, candidates, overlay, and fill-in all need no changes.

Start with `adb shell uiautomator dump` to see what the target app exposes. An adapter returning `null` means "not in a chat window"; returning an empty message list means "in a chat window but the tree has no message text" — only the latter triggers the OCR fallback.

</details>

<details>
<summary><b>Build and directory structure</b></summary>

JDK 17 + Android SDK (platform 35 / build-tools 35).

```bash
./gradlew assembleDebug      # app/build/outputs/apk/debug/app-debug.apk
./gradlew assembleRelease    # needs a signing properties file outside the repo, pointed to by JEV_KEYSTORE_PROPS
```

- `app/` — the Android app (Kotlin)
- `extension/` — Chrome / Firefox MV3 extension
- `mac/` — menu-bar app for Messages and WhatsApp Desktop
- `docs/` — design and acceptance docs
- `apk/` — signed release builds

</details>

## Known limitations

- Some Android skins freeze background processes even with keep-alive configured — interacting with the chat usually brings the overlay back.
- Feishu message text relies on OCR when the body is custom-drawn.
- Group chats are analyzed as if 1:1.
- Knowledge-base retrieval is tag/title substring matching, not semantic search.
- OCR only sees what's visible on screen; protected windows (`FLAG_SECURE`) can't be captured.

## License

Code is open-sourced under [MIT](LICENSE); see also [NOTICE](NOTICE).

**Disclaimer**: this project only handles chats on your own device that you already have the right to view. Follow the terms of service of each chat app, as well as local laws — the author is not responsible for how it's used.
