import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(readFileSync(join(dir, "../manifest.json"), "utf8"));
const background = readFileSync(join(dir, "../background.js"), "utf8");

test("Firefox can load the same unpacked folder as Chrome", () => {
  assert.equal(manifest.manifest_version, 3);
  assert.equal(manifest.sidebar_action.default_panel, "panel.html");
  assert.equal(manifest.side_panel.default_path, "panel.html");
  assert.ok(manifest.browser_specific_settings.gecko.id);
  assert.equal(manifest.background.service_worker, "background.js");
  assert.ok(manifest.content_scripts[0].matches.includes("https://www.instagram.com/*"));
});

test("background does not require Chrome's sidePanel API", () => {
  assert.match(background, /sidePanel\?\.setPanelBehavior/);
  assert.match(background, /sidebarAction/);
});
