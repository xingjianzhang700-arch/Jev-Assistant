(function () {
  var PAGE = "https://xingjianzhang700-arch.github.io/Jev-Assistant/use.html#j=";
  function side(left, right, width) {
    return width - right < left ? "me" : "other";
  }
  function box(el) {
    var r = el.getBoundingClientRect();
    return { left: r.left, right: r.right, width: r.width };
  }
  function text(el) {
    return (el && el.textContent || "").trim();
  }
  var host = location.hostname;
  var snap = null;
  if (host.endsWith("instagram.com")) {
    var grid = document.querySelector('div[role="grid"][aria-label^="Messages in conversation"]');
    if (!grid || !document.querySelector('div[role="textbox"][contenteditable="true"]')) {
      alert("Open an Instagram chat first, then click Jev.");
      return;
    }
    var g = box(grid);
    var messages = [];
    grid.querySelectorAll('[role="row"]').forEach(function (row) {
      var el = row.querySelector('div[dir="auto"]');
      var line = text(el);
      if (!line) return;
      var r = box(el);
      messages.push({ side: side(r.left - g.left, r.right - g.left, g.width), text: line });
    });
    var title = (grid.getAttribute("aria-label") || "").replace(/^Messages in conversation with\s*/, "").trim();
    snap = { title: title, messages: messages };
  } else if (host.endsWith("whatsapp.com")) {
    var main = document.querySelector("#main");
    var composer = document.querySelector('#main footer div[contenteditable="true"]');
    if (!main || !composer) { alert("Open a WhatsApp chat first, then click Jev."); return; }
    var wa = [];
    main.querySelectorAll(".message-in, .message-out").forEach(function (row) {
      var line = text(row.querySelector(".selectable-text"));
      if (!line) return;
      wa.push({ side: String(row.className).indexOf("message-out") >= 0 ? "me" : "other", text: line });
    });
    var titleEl = main.querySelector("header span[title]");
    snap = { title: titleEl ? (titleEl.getAttribute("title") || text(titleEl)) : "", messages: wa };
  } else if (host.endsWith("snapchat.com")) {
    var input = document.querySelector('[data-testid="chat-input"]')
      || document.querySelector('div[contenteditable="true"][aria-label="Send a Chat"]');
    if (!input) { alert("Open a Snapchat chat first, then click Jev."); return; }
    var sc = [];
    document.querySelectorAll('[data-testid="chat-message"]').forEach(function (row) {
      var line = text(row.querySelector('[data-testid="chat-message-text"]'));
      if (!line) return;
      sc.push({ side: row.getAttribute("data-from") === "me" ? "me" : "other", text: line });
    });
    var scTitle = document.querySelector('[data-testid="chat-title"]');
    snap = { title: text(scTitle), messages: sc };
  } else if (host.endsWith("messages.google.com")) {
    if (!document.querySelector("mws-message-compose textarea")) {
      alert("Open a Google Messages chat first, then click Jev.");
      return;
    }
    var gm = [];
    document.querySelectorAll("mws-message-wrapper").forEach(function (row) {
      var line = text(row.querySelector(".text-msg"));
      if (!line) return;
      gm.push({ side: row.getAttribute("is-outgoing") === "true" ? "me" : "other", text: line });
    });
    var gmTitle = document.querySelector("mws-conversation-header h2");
    snap = { title: text(gmTitle), messages: gm };
  }
  if (!snap || !snap.messages.length) {
    alert("Open a chat on Instagram, WhatsApp Web, Snapchat Web, or Google Messages, then click Jev.");
    return;
  }
  snap.messages = snap.messages.slice(-10);
  window.open(PAGE + encodeURIComponent(JSON.stringify(snap)));
})();
