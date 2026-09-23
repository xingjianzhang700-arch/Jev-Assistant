import { readFileSync } from "node:fs";
import { parseHTML } from "linkedom";

export function load(name) {
  const html = readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8");
  return parseHTML(html).document;
}

/** Layout for fixtures: the data-jev-rect the capture snippet recorded. */
export function fixtureRect(el) {
  const [left, top, right, bottom] = (el.getAttribute("data-jev-rect") ?? "0,0,0,0").split(",").map(Number);
  return { left, top, right, bottom, width: right - left, height: bottom - top };
}
