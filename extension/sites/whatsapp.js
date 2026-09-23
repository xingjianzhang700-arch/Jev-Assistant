// WhatsApp Web (web.whatsapp.com). Direction is marked on the row, so no
// layout is needed. Selectors are expected values, not yet confirmed on the
// live site — see test/fixtures/README.md.
// A chat is open only when the conversation footer has a compose box. The
// chat-list search box is outside #main, so it does not count.

export function composer(doc) {
  return doc.querySelector('#main footer div[contenteditable="true"]');
}

export function read(doc) {
  if (!composer(doc)) return null;
  const main = doc.querySelector("#main");
  const messages = [];
  for (const row of main.querySelectorAll(".message-in, .message-out")) {
    const text = (row.querySelector(".selectable-text")?.textContent ?? "").trim();
    if (!text) continue;
    const outgoing = String(row.className).includes("message-out");
    messages.push({ side: outgoing ? "me" : "other", text });
  }
  const titleEl = main.querySelector("header span[title]");
  const title = titleEl?.getAttribute("title")?.trim() || titleEl?.textContent.trim() || null;
  return { title, messages };
}
