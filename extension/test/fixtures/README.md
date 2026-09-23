# Test Fixtures

## Expected selectors (not yet confirmed on the live site)

| Site | Component | Selector | Notes |
|------|-----------|----------|-------|
| Google Messages | message | `mws-message-wrapper` with `is-outgoing="true\|false"` | Custom element marks each message |
| Google Messages | message text | `.text-msg` | Text content inside message wrapper |
| Google Messages | composer | `mws-message-compose textarea` | Input box |
| Google Messages | conversation title | `mws-conversation-header h2` | Conversation name/contact |
| Instagram | thread grid | `div[role="grid"][aria-label^="Messages in conversation"]` | Grid of message rows |
| Instagram | thread title | aria-label of grid after "Messages in conversation with " | Extracts contact name |
| Instagram | message row | `[role="row"]` | Each row is a message |
| Instagram | message text | `div[dir="auto"]` | Text content inside row |
| Instagram | composer | `div[role="textbox"][contenteditable="true"]` | Input box |
| Instagram | thread path | `/direct/t/…` | Direct message URL pattern |
| WhatsApp Web | composer | `#main footer div[contenteditable="true"]` | Chat-list search is outside `#main` |
| WhatsApp Web | message | `.message-in` / `.message-out` | Side comes from the row class |
| WhatsApp Web | message text | `.selectable-text` | |
| WhatsApp Web | title | `#main header span[title]` | `title` attribute |
| Snapchat Web | composer | `[data-testid="chat-input"]` or Send a Chat textbox | No Snapchat Mac app |
| Snapchat Web | message | `[data-testid="chat-message"]` | `data-from="me"` is outgoing |
| Snapchat Web | message text | `[data-testid="chat-message-text"]` | |

## Fixtures

### Hand-written fixtures

- **gmessages_thread.html**: Conversation with 3 messages from Google Messages. Contains a header with title "Mom", a message list with alternating outgoing/incoming messages, and a composer. Used to verify message reading and composer detection.
- **gmessages_list.html**: Conversation list page from Google Messages. Contains only a list item with no message wrappers or composer. Used to verify that list pages return `null` (not a conversation).
- **instagram_thread.html**: Direct message thread with 3 messages from Instagram. Contains a grid with title "alex.r", three message rows with left/right positioning to indicate me/other sides, and a textbox composer. Used to verify message layout-based side detection and title extraction.
- **instagram_empty_thread.html**: Empty direct message thread from Instagram. Contains only a textbox composer with no message grid. Used to verify that empty threads return `{ title: null, messages: [] }`.

### Real-fixture tests (not yet captured)

- **gmessages_thread_real.html** (future): Captured from live Google Messages conversation
- **gmessages_list_real.html** (future): Captured from live Google Messages list page

## Owner: capture real pages

To verify selectors work on the live site:

1. Open Google Messages (https://messages.google.com) in Chrome with a test conversation
2. Run the capture snippet from `docs/superpowers/plans/2026-09-22-laptop-chrome-extension.md` Task 3 Step 1 in DevTools:
   - This records `data-jev-rect` layout annotations
   - Copies the DOM structure to clipboard
3. Save the captured HTML as:
   - `gmessages_thread_real.html` for a real conversation
   - `gmessages_list_real.html` for the conversation list
4. Scrub real names and phone numbers from the saved file
5. Check selectors with grep:
   ```bash
   grep -c "mws-message-wrapper" gmessages_thread_real.html
   grep "is-outgoing" gmessages_thread_real.html
   grep "text-msg" gmessages_thread_real.html
   ```
6. **Stop if**: Google Messages content is inside shadow roots (clone shows empty `mws-*` tags) — this would require a different approach
7. Add real-fixture tests to `gmessages.test.js` and verify they pass
8. If a real-fixture test fails, fix the selectors (not the test) and re-run

## Notes

- Fixtures use `linkedom` to parse HTML in Node.js tests
- The `fixtureRect` helper in `helpers.js` reads `data-jev-rect` attributes for layout-based tests (used by Instagram, not Google Messages)
- Google Messages uses custom elements (`mws-*`) which makes selectors stable without layout analysis
