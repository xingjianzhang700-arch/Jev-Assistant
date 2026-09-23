// Pure logic shared by the background worker, the site readers and the tests.
// No chrome.* and no DOM here. Prompt text comes only from brain.json.

/** "me" when the bubble hugs the right edge more than the left. */
export function sideByEdges(left, right, width) {
  return width - right < left ? "me" : "other";
}

export function signature(messages) {
  return messages.slice(-6).map((m) => `${m.side}:${m.text}`).join("|");
}

export function buildState(messages, relationship) {
  const last = messages.slice(-10);
  return {
    chat: {
      relationship,
      messages: last.map((m) => ({ from: m.side, text: m.text })),
      latest_from: last.at(-1)?.side ?? "other",
    },
  };
}

export function judgeBody(brain, model, messages, relationship) {
  return { model, state: buildState(messages, relationship), questions: brain.judge_questions };
}

export function rankBody(brain, model, messages, relationship, candidates) {
  const [a, b, c] = candidates;
  return {
    model,
    state: buildState(messages, relationship),
    questions: {
      best_reply: {
        type: "choice",
        instructions: brain.rank_instructions,
        criteria: { reply_a: a, reply_b: b, reply_c: c },
      },
    },
  };
}

export function draftBody(brain, model, messages, relationship) {
  const conversation = messages.slice(-10)
    .map((m) => (m.side === "me" ? "Me" : "Them") + ": " + m.text).join("\n");
  const user = brain.draft_user_template
    .replace("{relationship}", () => relationship)
    .replace("{conversation}", () => conversation);
  return {
    model,
    temperature: 0.8,
    messages: [
      { role: "system", content: brain.draft_system },
      { role: "user", content: user },
    ],
  };
}

/** Same rules as Android's ReplyClient.parseThree. */
export function parseThree(content, fallback) {
  let out = [];
  let parsed = false;
  const a = content.indexOf("["), b = content.lastIndexOf("]");
  if (a >= 0 && b > a) {
    try { out = JSON.parse(content.slice(a, b + 1)).map((s) => String(s).trim()); parsed = true; } catch { }
  }
  if (!parsed) {
    out = content.split("\n").map((l) => l.trim().replace(/^[-*123. "]+/, "")).filter(Boolean);
  }
  out = out.slice(0, 3);
  while (out.length < 3) out.push(fallback);
  return out;
}

export function rankReplies(bestReply, candidates) {
  const keys = ["reply_a", "reply_b", "reply_c"];
  const p = bestReply?.probabilities ?? {};
  return candidates
    .map((text, i) => ({ text, prob: Number(p[keys[i]] ?? 0) }))
    .sort((x, y) => y.prob - x.prob);
}

export function moodPercent(answer) {
  if (!answer?.choice) return null;
  const raw = answer.probabilities?.[answer.choice] ?? answer.confidence;
  const n = Number(raw);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
}

export function summarize(a) {
  return {
    intent: a.true_intent?.choice ?? null,
    intentConfidence: a.true_intent?.confidence ?? null,
    risk: a.danger_level?.score ?? null,
    needs: a.she_needs?.choice ?? null,
    bestAction: a.best_action?.choice ?? null,
    specificsOk: a.should_reply_now?.noul ?? null,
    tensionResolved: a.tension_resolved?.noul ?? null,
    mood: a.mood?.choice ?? null,
    moodPct: moodPercent(a.mood),
  };
}
