<div align="center">

<img src="docs/images/logo.png" width="150" alt="Jev Assistant" />

# Jev Assistant

**Jev reads the open chat, judges what the other person wants, and suggests three replies. You choose one. Jev fills the box. You press send.**

</div>

## Demo

Nine seconds, fictional chat. Jev reads the thread, names the intent and risk, ranks three replies, and fills the box. The Send button is never pressed.

![Jev reads a chat, ranks three replies, and fills the box without sending](docs/demo.gif)

[Play the video](docs/demo.mp4)

## Contents

- [What Jev does](#what-jev-does)
- [Connect an OpenRouter API key](#connect-an-openrouter-api-key)
- [Android](#android)
- [Laptop](#laptop)
- [Mac](#mac)
- [Supported chats](#supported-chats)
- [How a suggestion is made](#how-a-suggestion-is-made)
- [FAQ](#faq)
- [Limitations](#limitations)
- [License](#license)

## What Jev does

- **It judges before it writes.** A judgment model names the other person's intent, the risk, and whether to reply now. A second model drafts three replies. The judgment model ranks them.
- **It only reads the screen.** No hooking, no repackaging, no private APIs, no reading the chat app's database. Android uses the accessibility service. The browser extension reads the page. The Mac app reads Messages or WhatsApp Desktop through Accessibility.
- **Sending stays yours.** Fill writes the chosen reply into the compose box, or copies it if the box cannot be written. Jev never presses Send.
- **Your key, your quota.** Judge, reply, and vision can each use a different endpoint. One OpenRouter key is enough: leave the reply and vision keys blank and they reuse the judge key.
- **Notes stay on the device.** A local knowledge base and contact notes can be included in an analysis. Chat text is sent only to the endpoint you configured, at the moment you analyze.

## Connect an OpenRouter API key

Jev does not ship a key. Analysis calls [OpenRouter](https://openrouter.ai/) with yours. OpenRouter bills the models against your credit.

**1. Create the key.** Sign in at [openrouter.ai](https://openrouter.ai/), open [openrouter.ai/keys](https://openrouter.ai/keys), and choose **Create Key**. Copy the key. It starts with `sk-or-v1-`. You can set a monthly credit limit on that same page so a run cannot spend without a cap.

**2. Paste it once.**

| Where you use Jev | Where the key goes |
|---|---|
| Android | Open the app → Settings → Judge API → paste the key. Leave Reply API and Vision API empty. |
| Chrome | `chrome://extensions` → Jev Assistant → Details → Extension options. Paste the key into **Judge API key** and save. |
| Firefox | Extensions → Jev Assistant → Options. Paste the key into **Judge API key** and save. Firefox does not share Chrome's saved key. |
| Mac | Menu bar **Jev** → **Set Judge API key…** → Paste → Save. Leave **Set Reply API key** empty to reuse the judge key. |

**3. Analyze a chat.** Leave a conversation in front (a Direct thread, a WhatsApp chat, or Messages). Open Jev and choose Analyze. The panel shows the intent, the risk, and three ranked replies. **Fill** puts the text in the compose box. You send it yourself.

The default judge and reply models are paid OpenRouter models. To spend less, change the model id in settings to one ending in `:free`. An empty Reply key always reuses the Judge key.

## Android

The phone needs Android 11 or newer.

1. On the phone, open [the release APK](apk/jev-assistant-v1.3-release.apk) and download it.
2. Tap the download. If Android blocks it, allow installs from the browser, then open the file.
3. Paste the OpenRouter key in Settings → Judge API.
4. Turn on **Accessibility** and **Display over other apps**.

From a computer you can also run:

```bash
adb install -r apk/jev-assistant-v1.3-release.apk
```

That APK is the older v1.3 build. It does not include the later WhatsApp and Snapchat readers. Those readers are in the source tree and need a new build:

```bash
./gradlew assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Laptop

The extension is the same folder for Chrome and Firefox. It reads WhatsApp Web, Snapchat Web, Instagram Direct, and Google Messages for web.

**Chrome.** Open `chrome://extensions`, turn on Developer mode, choose **Load unpacked**, and select the `extension/` folder. Click the Jev toolbar icon to open the side panel.

**Firefox.** Open `about:debugging#/runtime/this-firefox`, choose **Load Temporary Add-on…**, and pick `extension/manifest.json`. A temporary add-on is removed when Firefox quits. Load that file again after a restart. Click the Jev toolbar icon to open the sidebar.

Paste the OpenRouter key in the extension options, as in [Connect an OpenRouter API key](#connect-an-openrouter-api-key). Leave the Reply key blank to reuse it.

An iPhone cannot let an app read WhatsApp or Snapchat. On a computer, use WhatsApp Desktop or WhatsApp Web, or Snapchat Web while signed in. Jev reads that window.

**Fill** only writes into the site's own message box. It does not press Enter and it does not click Send.

## Mac

The menu-bar app reads Apple Messages (iMessage, and SMS forwarded from an iPhone) and WhatsApp Desktop. Snapchat on a Mac is the browser extension. There is no Snapchat Mac app.

Requirements: macOS 14 or newer, Messages signed in, and SMS forwarding turned on if you want SMS threads.

```bash
bash mac/package.sh
```

Open `mac/build/Jev Assistant.app`. A **Jev** item appears in the menu bar. Grant Accessibility under System Settings → Privacy & Security → Accessibility, then set the Judge API key from the Jev menu. Each rebuild changes the ad-hoc signature, so macOS may ask for Accessibility again.

The menu bar follows Messages and WhatsApp Desktop only. Switching to another app stops the current analysis. Instagram is the browser extension.

**Fill** writes the compose field, or copies the text if the field cannot be set. It does not press Return.

## Supported chats

| Chat | Where | How it is read |
|---|---|---|
| WhatsApp | Android app, WhatsApp Desktop, WhatsApp Web | Accessibility on Android and Mac. The page DOM in Chrome and Firefox. |
| Snapchat | Android app, Snapchat Web | Accessibility on Android. The page DOM in the browser. |
| Instagram | Android app, instagram.com Direct | Accessibility on Android. The page DOM in the browser. |
| SMS / iMessage | Google Messages, Apple Messages | Accessibility on Android and Mac. Google Messages for web in the browser. |
| QQ, X, Feishu | Android | Accessibility. Feishu falls back to on-device OCR when the message text is drawn rather than exposed. |
| Any other app | Android | Overlay menu **Read screen once**. Manual. It does not separate you from the other person. |

Jev only reads chats already open on your own device.

## How a suggestion is made

```
open chat  →  read the recent messages
           →  judge intent, risk, needs, and whether to reply
           →  draft 3 replies
           →  rank those 3
           →  show them
           →  Fill writes the box
           →  you send
```

One adapter per app or site turns the window into a title plus a list of who said what. Everything after that is shared. The judgment call asks only multiple-choice, score, and yes/no questions. The reply model drafts the three candidates.

<details>
<summary><b>Add another Android chat app</b></summary>

1. Implement `ChatAppAdapter` in `app/src/main/java/com/jev/probe/capture/`. `pkg` is the package name. `extract` returns the title and messages, or `null` when the screen is not a chat.
2. Register it in `ChatCaptureService`.
3. Judgment, ranking, the overlay, and Fill stay as they are.

</details>

## FAQ

<details>
<summary><b>Will it send messages for me?</b></summary>

No. Fill only puts the selected reply in the input box. You tap send.

</details>

<details>
<summary><b>Does it need root?</b></summary>

No. It does not modify the chat app and it does not inject into its process.

</details>

<details>
<summary><b>Where does the chat text go?</b></summary>

Only to the API endpoint you saved, and only when you run an analysis. Jev has no server of its own. Local history is off until you turn it on, and then it stays in the app's private storage.

</details>

<details>
<summary><b>Does the app cost money?</b></summary>

The app is free. OpenRouter charges for the model calls on your key. Set a credit limit when you create the key.

</details>

## Limitations

- The shipped Android APK is v1.3 and does not contain the later WhatsApp and Snapchat readers. Build from source for those.
- Some Android skins freeze the background process. Opening the chat again brings the overlay back.
- Group chats are read as if they were a one-to-one thread.
- Knowledge-base matching is by tag and title text, not by meaning.
- OCR only sees what is on screen. Windows marked secure cannot be captured.
- Firefox add-ons loaded from this folder are temporary and disappear when Firefox quits.

## License

Code is under [MIT](LICENSE). See also [NOTICE](NOTICE).

This project only handles chats on your own device that you already have the right to view. Follow each app's terms and local law.
