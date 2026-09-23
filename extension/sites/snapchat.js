// Snapchat Web (web.snapchat.com). Selectors are expected values, not yet
// confirmed on the live site — see test/fixtures/README.md.
// A chat is open only when the "Send a Chat" box is on screen. There is no
// Snapchat Mac app; this page is how a computer reads Snapchat.

export function composer(doc) {
  return doc.querySelector('[data-testid="chat-input"]')
    || doc.querySelector('div[contenteditable="true"][aria-label="Send a Chat"]');
}

export function read(doc) {
  if (!composer(doc)) return null;
  const messages = [];
  for (const row of doc.querySelectorAll('[data-testid="chat-message"]')) {
    const text = (row.querySelector('[data-testid="chat-message-text"]')?.textContent ?? "").trim();
    if (!text) continue;
    messages.push({ side: row.getAttribute("data-from") === "me" ? "me" : "other", text });
  }
  const title = doc.querySelector('[data-testid="chat-title"]')?.textContent.trim() || null;
  return { title, messages };
}
