# Mac Messages fixtures

Hand-written Accessibility trees for `MessagesApp.parse`. Roles and layout are **expected values**, not yet verified on a live Messages window.

## Hand-written fixtures

| File | Purpose |
|---|---|
| `messages_window.json` | Open conversation with composer + transcript bubbles (title Sam; other / me / other). |
| `messages_no_convo.json` | Sidebar + search only — no composer → `parse` returns `nil`. |
| `messages_unreadable.json` | Composer present but empty transcript → `parse` returns empty messages. |
| `messages_tahoe.json` | Live Sequoia/Tahoe shape: `TranscriptCollectionView` + editable `CKBalloonTextView` + `messageBodyField`. |
| `messages_wide_window.json` | Wide AX transcript with a gutter past the balloon column; left = other, right-aligned = me; centered emoji must not flip sides. Fake short lines only. |

## Expected roles (parser assumptions)

- Sidebar: scroll area for the conversation list, with a search field of subrole `AXSearchField`.
- Transcript: `TranscriptCollectionView` (Tahoe) or a scroll area whose bubbles are `AXTextArea`s.
- Bubbles: `CKBalloonTextView` (editable on Tahoe) or non-editable `AXTextArea`.
- Header: `ConversationTitle` button, or `AXStaticText` above the transcript.
- Composer: `messageBodyField`, never a balloon or `AXSearchField`.
- Side: outgoing balloons share a trailing (right) edge inside the column → `me`; leading (left) balloons → `other`. Window width is not used (`sidesByBalloonEdges`). Emoji-only stickers inherit a neighbor's side and do not define the trailing edge.

## Real dumps — pending owner

Do **not** commit until names/numbers are scrubbed. Capture requires Accessibility for the terminal (or host app) under System Settings → Privacy & Security → Accessibility. Agents do not change those settings.

1. Open Messages on a **test conversation** (iMessage or SMS) with messages from both sides, ending with one from the other person:

```bash
cd mac && swift run JevMac --dump Fixtures/messages_window_real.json
```

2. Click a sidebar spot with no conversation selected (or open a new empty message window):

```bash
swift run JevMac --dump Fixtures/messages_no_convo_real.json
```

Expected: `wrote … (N elements)` with N in the hundreds. If N is under ~20, Messages isn't exposing its tree — stop and report.

3. Confirm layout (roles / text fields) against the expected roles above, then add JevChecks cases that load the real files.

`messages_window_real.json` / `messages_no_convo_real.json` are not in this tree yet.
