// Renders chrome.storage.session "view". Page-derived text only ever goes in via textContent.
const brain = await fetch("brain.json").then((r) => r.json());
const $ = (id) => document.getElementById(id);
const label = (group, key) => brain.labels?.[group]?.[key] ?? key;
const el = (tag, text, cls) => { const e = document.createElement(tag); e.textContent = text; if (cls) e.className = cls; return e; };

function render(view) {
  $("title").textContent = view?.title ? `Jev · ${view.title}` : "Jev";
  const body = $("body");
  body.replaceChildren();
  body.className = "";
  if (!view) { body.append(el("div", "Open an Instagram or Google Messages conversation.", "sub")); return; }
  if (view.error) { body.append(el("div", "Something went wrong", "err"), el("div", view.error, "sub")); return; }
  if (view.status) { body.append(el("div", view.status, "sub")); return; }
  const s = view.summary ?? {};
  if (s.moods?.length) {
    const row = el("div", "", "moods");
    row.append(el("span", "Mood:", "mood-label"));
    for (const m of s.moods) {
      const name = label("mood", m.key);
      row.append(el("span", m.pct == null ? name : `${name} ${m.pct}%`, "mood"));
    }
    body.append(row);
  } else if (s.mood) {
    const row = el("div", "", "moods");
    row.append(el("span", "Mood:", "mood-label"));
    row.append(el("span", s.moodPct == null ? label("mood", s.mood) : `${label("mood", s.mood)} ${s.moodPct}%`, "mood"));
    body.append(row);
  }
  if (s.intent) body.append(el("div", `Their real intent: ${label("intent", s.intent)}`));
  const bits = [];
  if (s.risk != null) bits.push(`Risk ${Math.round(s.risk)}/9`);
  if (s.needs) bits.push(`Needs ${label("needs", s.needs)}`);
  if (s.bestAction) bits.push(label("action", s.bestAction));
  if (s.specificsOk != null) bits.push(s.specificsOk >= 0.5 ? "OK to give specifics" : "Hold off on specifics");
  if (bits.length) body.append(el("div", bits.join(" · "), "sub"));
  if (s.tensionResolved >= 0.7) body.append(el("div", "✓ Tension resolved", "sub"));
  body.append(el("div", "Suggested replies (ranked by Jev)", "sub"));
  for (const r of view.replies ?? []) {
    const box = el("div", "", "reply");
    box.append(el("div", `${Math.round(r.prob * 100)}%  ${r.text}`));
    const fill = el("button", "Fill");
    fill.onclick = () => fillReply(r.text);
    const copy = el("button", "Copy");
    copy.onclick = () => navigator.clipboard.writeText(r.text).then(() => note("Copied"));
    box.append(fill, copy);
    body.append(box);
  }
}

const note = (t) => { $("note").textContent = t; };

async function fillReply(text) {
  const { snap } = await chrome.storage.session.get("snap");
  let ok = false;
  try { ok = (await chrome.tabs.sendMessage(snap.tabId, { type: "fill", text }))?.ok; } catch { ok = false; }
  if (ok) return note("Filled in. Review it, then send it yourself");
  await navigator.clipboard.writeText(text);
  note("Copied. Click the message box and paste");
}

$("analyze").onclick = () => chrome.runtime.sendMessage({ type: "analyzeNow" });
chrome.storage.session.onChanged.addListener((c) => { if (c.view) render(c.view.newValue); });
render((await chrome.storage.session.get("view")).view);
