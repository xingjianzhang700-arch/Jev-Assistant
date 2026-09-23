# Test Fixture Dumps

This directory contains XML accessibility trees for testing chat app adapters. Fixtures are hand-written representations of real UI states used for unit tests.

## Expected Resource IDs (not yet verified on a device)

| App | Package | Message Body | Composer | Thread Title |
|-----|---------|--------------|----------|--------------|
| Instagram Direct | `com.instagram.android` | `com.instagram.android:id/direct_text_message_text_view` | `com.instagram.android:id/row_thread_composer_edittext` | `com.instagram.android:id/header_title` |
| Google Messages | `com.google.android.apps.messaging` | `:id/message_text` | `:id/compose_message_text` | `:id/conversation_title` |
| WhatsApp | `com.whatsapp` (and `com.whatsapp.w4b`) | `:id/message_text` | `:id/entry` | `:id/conversation_contact_name` |
| Snapchat | `com.snapchat.android` | `:id/chat_message_text` | `:id/chat_input_text_field` | `:id/chat_title` |

## Hand-Written Fixtures

### Instagram Direct

- **instagram_thread.xml** – A thread with 3 messages: two from "other" (left side, narrow bubble), one from "me" (right side, wide bubble). Contains title "alex.r", timestamp, and composer EditText. Width: 1080px.

- **instagram_inbox.xml** – The DM list screen with search EditText, username row, and digest row. No thread composer present. Width: 1080px.

- **instagram_empty_thread.xml** – A thread with title but no readable message bodies (e.g., only photos). Has composer EditText but no body TextViews. Returns empty message list to trigger OCR fallback. Width: 1080px.

### Google Messages

- **messages_thread.xml** – A conversation with 3 messages: one from "other" (left side), one from "me" (right side), one from "other" (left side). Contains title "Mom", status line (skipped by id), and composer EditText. Width: 1080px.

- **messages_list.xml** – The conversation list screen with no thread composer. Contains app header "Messages", conversation name, and snippet. Returns null. Width: 1080px.

### General

- **sample_bubbles.xml** – Placeholder fixture for generic bubble testing.

## Owner: Capture real dumps

To add a real device dump:

1. Open the chat screen on a USB-debugging phone.
2. Run: `adb shell uiautomator dump /sdcard/d.xml && adb pull /sdcard/d.xml app/src/test/resources/dumps/<name>_real.xml`
3. Use a test conversation and scrub names before committing.
4. Find resource IDs: `grep -o 'resource-id="[^"]*"' <file> | sort | uniq -c | sort -rn | head -40`
5. If a dump has only 1-2 nodes (tree hidden), use the app's bubble menu OCR instead.
6. Update the Expected IDs table above if new IDs are found.
7. Add regression tests to the adapter's `*ParseTest.kt` file with `realThreadDump` / `realInboxDump` tests asserting visible messages from this README.
8. Fix constants in the adapter (not test values) if the new dump's structure differs.
