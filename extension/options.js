import { customOrigins } from "./lib/origins.js";

const brain = await fetch("brain.json").then((r) => r.json());
const TEXT = ["judgeKey", "replyKey", "relationship", "judgeUrl", "judgeModel", "replyUrl", "replyModel"];
const PLACEHOLDER = {
  relationship: brain.default_relationship, judgeUrl: brain.judge_url_default,
  judgeModel: brain.judge_model_default, replyUrl: brain.reply_url_default, replyModel: brain.reply_model_default,
};
const $ = (id) => document.getElementById(id);

const saved = await chrome.storage.local.get([...TEXT, "auto"]);
for (const k of TEXT) { $(k).value = saved[k] ?? ""; $(k).placeholder = PLACEHOLDER[k] ?? ""; }
$("auto").checked = saved.auto ?? true;

$("save").onclick = async () => {
  const values = Object.fromEntries(TEXT.map((k) => [k, $(k).value.trim()]));
  const gate = customOrigins(values.judgeUrl, values.replyUrl);
  if (gate.error) {
    $("status").textContent = gate.error;
    return;
  }
  if (gate.origins.length && !(await chrome.permissions.request({ origins: gate.origins }))) {
    $("status").textContent = "Permission for the custom API host was denied; not saved.";
    return;
  }
  await chrome.storage.local.set({ ...values, auto: $("auto").checked });
  $("status").textContent = "Saved.";
};
