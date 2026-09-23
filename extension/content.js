// Classic content script. Pulls the ES modules in through dynamic import
// (they are listed in web_accessible_resources). Never sends a message.
(async () => {
  const url = (p) => chrome.runtime.getURL(p);
  const { signature } = await import(url("lib/core.js"));
  const sites = {
    "www.instagram.com": "sites/instagram.js",
    "messages.google.com": "sites/gmessages.js",
    "web.whatsapp.com": "sites/whatsapp.js",
    "web.snapchat.com": "sites/snapchat.js",
  };
  const siteFile = sites[location.host];
  if (!siteFile) return;
  const site = await import(url(siteFile));
  const rectOf = (el) => el.getBoundingClientRect();
  let timer = 0;
  let lastSig = null;

  function capture() {
    const snap = site.read(document, rectOf, location.pathname);
    if (!snap) return;
    const sig = (snap.title ?? "") + "#" + signature(snap.messages);
    if (sig === lastSig) return;
    lastSig = sig;
    chrome.runtime.sendMessage({
      type: "snapshot",
      snapshot: { ...snap, sig, latestFrom: snap.messages.at(-1)?.side ?? null },
    });
  }

  // Instagram and Google Messages are single-page apps: watch the DOM, debounce bursts.
  new MutationObserver(() => { clearTimeout(timer); timer = setTimeout(capture, 800); })
    .observe(document.body, { childList: true, subtree: true, characterData: true });
  capture();

  chrome.runtime.onMessage.addListener((msg, _sender, reply) => {
    if (msg.type === "fill") reply({ ok: fill(site.composer(document), msg.text) });
  });

  /** Put text in the box. Never presses Enter, never clicks send. */
  function fill(box, text) {
    if (!box) return false;
    box.focus();
    if (box instanceof HTMLTextAreaElement || box instanceof HTMLInputElement) {
      // The native setter, so React/Angular see the change.
      Object.getOwnPropertyDescriptor(Object.getPrototypeOf(box), "value").set.call(box, text);
      box.dispatchEvent(new Event("input", { bubbles: true }));
      return box.value === text;
    }
    // contenteditable (Instagram's rich-text editor): insertText keeps its state in sync.
    document.execCommand("selectAll", false);
    document.execCommand("insertText", false, text);
    return box.textContent.includes(text);
  }
})();
