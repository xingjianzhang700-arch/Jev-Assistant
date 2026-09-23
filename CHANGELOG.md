# Changelog

Format: each version is grouped into Added / Improved / Fixed / Known limitations / Download, written in plain language, not a commit list.

## v1.4 — 2026-09-22
- English UI, prompts and docs. Replies follow the language of the conversation.
- New: Instagram Direct and Google Messages (SMS) are read automatically.
- English timestamps and read receipts ("9:41 AM", "Seen", "Yesterday") are ignored in capture and OCR.
- New: Chrome extension for Instagram web and Google Messages for web.
- New: Mac menu-bar app for Apple Messages (iMessage and forwarded SMS).
- New: WhatsApp and Snapchat on Android, WhatsApp Web and Snapchat Web in the Chrome extension (macOS and Windows), and WhatsApp Desktop in the Mac menu-bar app. View ids and web selectors are expected values, not yet verified on a device.

## v1.3 — 2026-09-22

**Added**
- Fully configurable endpoints: the address, key, and model for the judge / reply / vision endpoints can each be set independently, with four built-in presets (OpenRouter, TypeSafe direct, DeepSeek official, Tongyi-compatible), each with its own one-tap "connectivity test." One key is enough: leaving reply and vision blank makes them inherit the judge endpoint's key. Upgrading automatically migrates the old key into the new config — no need to re-enter it.
- Knowledge base + linked context: you can maintain local notes (taggable, with an "always-on" option to include every time) and contact profiles (name, cross-app aliases, relationship, notes); analysis automatically feeds the model any matching notes and that person's chat history, so replies stay consistent with what's in the knowledge base. History is off by default; once enabled, it's still only stored locally on the phone, and can be cleared with one tap. The overlay panel shows "Knowledge N · History M," and long-pressing a bubble saves the current chat as a contact directly.
- OCR fallback: for screens where the accessibility tree has no message text (e.g. Feishu), it automatically takes a screenshot and reads the text with an offline Chinese recognition model — no network access, no image upload. Any other app can also trigger a one-off "screenshot recognition" manually from the overlay menu.

**Fixed**
- Fixed several issues found during real-device verification: some screens briefly show a temporary title (e.g. a "connecting" message) that was polluting the chat record; the chat-list screen could mistakenly trigger analysis; the panel occasionally went blank after switching chats; WeChat group titles were sometimes captured incorrectly; the key input field didn't display fully; the layout overlapped the status bar on some devices.

**Known limitations**
- Larger install size: about 12 MB up to about 25 MB (offline Chinese recognition model), arm64 devices only.
- After upgrading to this version, accessibility needs to be turned off and back on for the new screenshot capability to take effect.
- The new screenshot recognition can only read what's currently visible on screen; the cut-off part of a long message can't be read, and there are occasional misreads.
- X (Twitter) has only been verified on the Chinese UI so far; the English UI and group DMs haven't been tested; the long-standing Xiaomi / HyperOS background-freeze issue still exists.

**Download**: [jev-assistant-v1.3-release.apk](https://github.com/jev-chat/jev-chat-jarvis/raw/v1.3/apk/jev-assistant-v1.3-release.apk)

## v1.2 — 2026-09-21

**Added**
- X (Twitter) DM support: verified on a real device end to end — reading messages, judging, drafting reply candidates, and filling the input box all work. Only the Chinese UI has been verified so far.

**Known limitations**
- Group DMs and the English UI are still unverified.
- Xiaomi / HyperOS's battery-saving policy can still freeze the background process, occasionally causing new messages to be missed.

**Download**: [jev-assistant-v1.2-release.apk](https://github.com/jev-chat/jev-chat-jarvis/raw/v1.2/apk/jev-assistant-v1.2-release.apk)

## v1.1 — 2026-09-21

**Added**
- Mobile QQ support: verified on a real device that reading messages, judging, drafting reply candidates, and filling the input box all work in group chats. 1:1 chat was adapted using the same structure but hasn't been specifically verified.
- Refactored the capture layer into a "one adapter per app" structure, so adding a new chat app going forward will be faster.

**Known limitations**
- QQ 1:1 chat is unverified on a real device.

**Download**: [jev-assistant-v1.1-release.apk](https://github.com/jev-chat/jev-chat-jarvis/raw/v1.1/apk/jev-assistant-v1.1-release.apk)

## v1.0 — 2026-09-21

**Added**
- First usable version: works end to end on WeChat Android (verified on a real 8.0.78 device) — reads chat bubbles → the Jev judgment model gives the real intent, risk level (1–9), what the other person wants, whether to reply right now, and the best action (about 1 second) → a generation model (DeepSeek) drafts 3 reply candidates → Jev ranks the candidates → shown in a translucent overlay → filled into the input box with one tap.
- The overlay can be dragged, its opacity is adjustable, it supports a chat allowlist and an auto/manual analysis toggle, and a foreground service keeps it from being killed by the system.
- Filling the input box tries the system API first, falling back automatically to clipboard-paste on failure — neither method ever sends automatically.

**Known limitations**
- Battery-saving policies on Chinese Android skins like Xiaomi / HyperOS can freeze the background process, occasionally causing new messages to be missed.
- Group chats are currently analyzed as if 1:1, so results may not be accurate.
- The Jev judgment model is primarily trained on English; judgment quality on Chinese conversations still needs calibration with real conversation data.

**Install**: Android 11+, requires an [OpenRouter](https://openrouter.ai/) API key.

**Download**: [jev-assistant-v1.0-release.apk](https://github.com/jev-chat/jev-chat-jarvis/raw/v1.0/apk/jev-assistant-v1.0-release.apk)

---

See GitHub Releases and commits for the full commit history.
