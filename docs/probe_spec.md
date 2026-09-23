# Probe app technical spec (P1 gate)

**Sole purpose**: answer one question — if we disguise ourselves as a system accessibility service, can we read WeChat 8.0.78's chat node text?

The result decides whether the whole project takes route A (real-time accessibility text, millisecond-scale) or route B (accessibility screenshot + local OCR, roughly 0.5s).

## Core mechanism: why "disguising" might work

Since WeChat 8.0.52, it obfuscates/hides the node tree for plain third-party accessibility services. The community workaround is to register the accessibility service's **fully-qualified class name** as the system's built-in one:

```
com.google.android.accessibility.selecttospeak.SelectToSpeakService
```

Key point: **Android identifies an accessibility service component by "package name/fully-qualified class name."** Our app's package name is `com.jev.probe`, and the service's fully-qualified class name is the string above, so the component is
`com.jev.probe/com.google.android.accessibility.selecttospeak.SelectToSpeakService`,
which **doesn't conflict** with the same-named class under the system TalkBack package — the two can coexist. This assumes WeChat only checks the class-name string, not the package name and signature. **Whether that assumption is correct is exactly what this probe is meant to test.**

An earlier community version used `com.google.android.marvin.talkback.TalkBackService`, but on Xiaomi devices this triggers a persistent on-screen "screen reading" notice — **don't use it.**

## Must run an A/B control

Testing only the disguised service can't prove disguising is the effective variable. Both services must exist, independently toggleable:

| Group | Fully-qualified service class name | Role |
|---|---|---|
| Experimental | `com.google.android.accessibility.selecttospeak.SelectToSpeakService` | Disguised |
| Control | `com.jev.probe.PlainAccessibilityService` | Plain-named |

Both groups' code logic must be **exactly identical** — only the class name and manifest registration differ. Only enable one at a time when testing.

## Feature list

1. **Node-tree dump**
   - Walk `rootInActiveWindow`, recursing into all children
   - For each node, record: `className`, `viewIdResourceName`, `text`, `contentDescription`, `packageName`, `bounds`, `isClickable`, `isEditable`, depth
   - Output JSON to `getExternalFilesDir(null)/dumps/dump_<group-name>_<timestamp>.json`
   - Also log a summary to logcat under the fixed tag `JEVPROBE`: total node count, count of nodes with text, and the first 10 characters of each of the first 10 text nodes
2. **Manual trigger**: register a BroadcastReceiver; `adb shell am broadcast -a com.jev.probe.DUMP` dumps the current foreground window immediately. This is the primary test method — don't rely on automatic event triggering.
3. **Event observation**: in `onAccessibilityEvent`, only log the event type and source package name to logcat — don't do heavy work inside the event callback.
4. **Screenshot capability verification**: on receiving the `com.jev.probe.SHOT` broadcast, call `AccessibilityService.takeScreenshot()` (API 30+) and save it as a PNG in the same directory. This verifies the feasibility of route B (the key point: this API doesn't prompt a screen-recording consent dialog).
5. **MainActivity**: three buttons — open the accessibility settings page, dump immediately, and show a summary of the most recent dump (node count, count of nodes with text). The UI can be ugly, that's fine.

## Configuration gotchas (easy to get wrong)

Two independent service configs under `res/xml/`:

- `android:canRetrieveWindowContent="true"` must be on
- `accessibilityFlags` must at least include `flagReportViewIds|flagRetrieveInteractiveWindows|flagIncludeNotImportantViews`
- `android:accessibilityEventTypes="typeAllMask"`
- **Don't** use `android:packageNames` to limit it to WeChat only — doing so removes the ability to run the control comparison against other apps, so you can't tell "WeChat is specifically blocking me" from "my service just isn't running."
- `android:isAccessibilityTool="true"` (API 29+), otherwise it gets miscategorized in the accessibility list on some ROMs
- `android:notificationTimeout` set to 100

Service declaration in the manifest:

```xml
<service
    android:name="com.google.android.accessibility.selecttospeak.SelectToSpeakService"
    android:exported="true"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter android:priority="10000">
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <meta-data android:name="android.accessibilityservice"
               android:resource="@xml/config_disguised" />
</service>
```

Same for the control group, just swap `android:name` and `@xml/config_plain`.

## Acceptance (real device)

Leave the phone sitting on **some WeChat chat window**, with only the experimental-group service enabled:

```
adb shell am broadcast -a com.jev.probe.DUMP
adb logcat -d -s JEVPROBE | tail -20
adb shell ls /sdcard/Android/data/com.jev.probe/files/dumps/
adb pull /sdcard/Android/data/com.jev.probe/files/dumps/<latest-file>
```

Verdict:
- **PASS**: node count > 20 and Chinese chat-bubble text is visible
- **FAIL**: node count ≤ 3, or all `text` fields are empty

Then disable the experimental group, enable only the control group, and repeat, recording the difference. Also run the same dump once each on a plain app (e.g. system Settings) for both service variants, as a baseline that "the service itself is working."

All four results must be recorded in the report:

| | WeChat chat screen | System Settings screen |
|---|---|---|
| Disguised service | ? | ? |
| Plain service | ? | ? |

## Red lines

- The probe is read-only: never call `performAction` (clicking, typing, and swiping are all forbidden)
- Never touch transfer, red-packet, or receiving-payment screens
- Dump files stay on the phone and locally — never upload to any server
- Never auto-send any message
