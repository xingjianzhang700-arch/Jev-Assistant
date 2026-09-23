export function customOrigins(judgeUrl, replyUrl) {
  const origins = [];
  for (const [field, raw] of [["Judge URL", judgeUrl], ["Reply URL", replyUrl]]) {
    const u = String(raw ?? "").trim();
    if (!u || u.startsWith("https://openrouter.ai/")) continue;
    let parsed;
    try { parsed = new URL(u); } catch { return { error: `Invalid URL: ${field}` }; }
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return { error: `Invalid URL: ${field}` };
    }
    origins.push(`${parsed.origin}/*`);
  }
  return { origins };
}
