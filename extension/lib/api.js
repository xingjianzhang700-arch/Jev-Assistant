// POST JSON. Retries 429/529 twice with backoff. Keys are never logged.
export async function postJson(url, key, body) {
  const headers = { Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
  if (url.includes("openrouter.ai")) {
    headers["HTTP-Referer"] = "https://jev-assistant.local";
    headers["X-Title"] = "Jev Assistant";
  }
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(url, { method: "POST", headers, body: JSON.stringify(body) });
    if ((res.status === 429 || res.status === 529) && attempt < 2) {
      await new Promise((r) => setTimeout(r, 1000 << attempt));
      continue;
    }
    const text = await res.text();
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 120)}`);
    return JSON.parse(text);
  }
}
