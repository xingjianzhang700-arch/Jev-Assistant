// Google Messages for web (messages.google.com). Custom elements mark each
// message and whether it is outgoing, so no layout is needed.
// Selectors are expected values, not yet confirmed on the live site — see test/fixtures/README.md to capture a real page and confirm them.

export function composer(doc) {
  return doc.querySelector("mws-message-compose textarea");
}

export function read(doc) {
  if (!composer(doc)) return null;
  const messages = [];
  for (const w of doc.querySelectorAll("mws-message-wrapper")) {
    const text = (w.querySelector(".text-msg")?.textContent ?? "").trim();
    if (text) messages.push({ side: w.getAttribute("is-outgoing") === "true" ? "me" : "other", text });
  }
  const title = doc.querySelector("mws-conversation-header h2")?.textContent.trim() || null;
  return { title, messages };
}
