// Instagram web Direct (instagram.com/direct/t/<id>/). Class names are
// generated, so this keys off ARIA roles and layout only.
// Selectors are expected values, not yet confirmed on the live site — see test/fixtures/README.md to capture a real page and confirm them.
import { sideByEdges } from "../lib/core.js";

const GRID = 'div[role="grid"][aria-label^="Messages in conversation"]';

export function composer(doc) {
  return doc.querySelector('div[role="textbox"][contenteditable="true"]');
}

export function read(doc, rectOf, path) {
  if (!/^\/direct\/t\//.test(path) || !composer(doc)) return null;
  const grid = doc.querySelector(GRID);
  if (!grid) return { title: null, messages: [] };
  const g = rectOf(grid);
  const title = (grid.getAttribute("aria-label") ?? "")
    .replace(/^Messages in conversation with\s*/, "").trim() || null;
  const messages = [];
  for (const row of grid.querySelectorAll('[role="row"]')) {
    const el = row.querySelector('div[dir="auto"]');
    const text = el?.textContent.trim();
    if (!text) continue;
    const r = rectOf(el);
    messages.push({ side: sideByEdges(r.left - g.left, r.right - g.left, g.width), text });
  }
  return { title, messages };
}
