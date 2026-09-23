# Task: build the Jev judgment layer's question set + calibration scaffolding (Python, runs on a PC)

You're at `H:\ai_tool\jev-android`. **Read `CLAUDE.md` and `docs/acceptance.md` first** — they contain the hard constraints and acceptance criteria.

## Background

We're building an assistant that sits alongside WeChat. After the other person sends a message, the program hands the last several messages of the conversation to **Jev** (TypeSafe's judgment model, which only answers multiple-choice / scoring / yes-no questions, never generates free text), gets back judgments like "what's her real intent, what's the danger level, should I reply right now, what's the best action," then hands 3 candidate replies to Jev to rank, and finally the person decides whether to send.

Jev's API (already verified working, don't change the protocol):

```
POST https://openrouter.ai/api/alpha/decisions
Authorization: Bearer $OPENROUTER_API_KEY
Content-Type: application/json

{
  "model": "typesafe/jev-1.13",
  "state": { ... any JSON, holds the chat content ... },
  "questions": {
    "question_name": {
      "type": "noul" | "choice" | "score",
      "instructions": "English question",
      "criteria": ...
    }
  }
}
```

- `noul`: yes/no question. `criteria` is optional, shaped like `{"true": "...", "false": "..."}`. Returns `{"type":"noul","noul":0.0~1.0}`
- `choice`: single choice. `criteria` is required, shaped like `{"key": "English description"}`, up to 255 items. Returns `{"type":"choice","choice":"key","probabilities":{...},"confidence":0~1}`
- `score`: tiered scoring. `criteria` is required and is an **ordered array**, 2-10 tiers, each tier written as a **concrete scenario**, not an abstract level (the official docs explicitly require this). Returns `{"type":"score","score":weighted_value,"legend":{...},"probabilities":{...},"confidence":0~1}`
- The response also carries `usage` (`input_tokens` / `output_tokens` / `cost`) and `provider`
- Error codes: 401 bad key, 422 invalid body, 429 rate limited, 529 overloaded. 429/529 need exponential backoff retries (up to 3 times)

**Already-verified pitfall (must be solved — this is the core value of this task)**: when tested on the conversation from the screenshot, `should_answer_now` (whether to answer with substance right now) came back 0.77, while `best_action` gave "check chat history first" at 0.60 — the two questions contradict each other; and at the end of the conversation, "what does she still need" gave "action" 0.62, beating "nothing" 0.38, but the correct answer is the latter. **The question wording needs to be rewritten, and the labeled set needs to squeeze out these kinds of contradictions.**

## Conventions (already settled, follow them)

1. **`instructions` and `criteria` are always in English** (Jev's primary training language is English; results are noticeably worse in Chinese); **keep the chat content inside `state` in its original Chinese** — don't translate it.
2. `state` is a JSON object shaped like:
   ```json
   {"chat": {"relationship": "...", "messages": [{"from": "her", "text": "original Chinese text"}, {"from": "me", "text": "..."}], "latest_from": "her"}}
   ```
   `from` only ever takes the values `her` / `me` (`her` refers to the other person generically, not gender-specific — describe it as "the other person" in prose). Carry at most the last 10 messages.
3. The question set is fixed at 7 judgment questions + 1 ranking question, sent all in one request (the officially recommended speculative fan-out, which saves both time and money):
   - `literal_question` (noul): is the other person's latest message literal, or is there a hidden meaning
   - `true_intent` (choice): the other person's real intent, 5-6 options
   - `danger_level` (score): how close this conversation is to a fight / hurt feelings, **10 tiers**, each tier written as a concrete scenario (e.g. "light or joking tone" → "clearly upset, a wrong reply will escalate things" → "already accusing or issuing an ultimatum")
   - `should_reply_now` (noul): whether to give a substantive reply right now
   - `best_action` (choice): the best next action, including "check chat history to confirm the facts," "commit directly with a concrete plan," "apologize first," "say less, don't overdo it," etc.
   - `she_needs` (choice): what the other person needs right now (an apology / concrete action / an explanation / nothing)
   - `tension_resolved` (noul): whether the tension has already been resolved
   - `best_reply` (choice): given 3 candidate reply texts, pick the most suitable one. The `criteria` keys are `reply_a/reply_b/reply_c`, and the values are the **candidate replies' original Chinese text** (this is the only place `criteria` is allowed to be Chinese, since that's the content being chosen between).
4. **Questions must not contradict each other**: `should_reply_now`'s wording must be scoped to "whether to give substantive content," and `best_action`'s options must not reintroduce the "should I reply now" dimension — they should only describe the type of action. `she_needs` must have a clear "nothing / this has already blown over" option, and the instructions must spell out "if the other person has already indicated they're satisfied, pick nothing."
5. 20-second timeout; a failed request needs a readable error. **Under no circumstances may the key be printed to stdout or written to a file.**

## Deliverables (only touch the `tools/jev/` directory — don't touch `app/`, `gradle/`, or any file at the repo root)

1. `tools/jev/jev_client.py`
   - `ask(state: dict, questions: dict, timeout=20) -> dict`: standard-library `urllib` only, no `requests`
   - reads the key from the `OPENROUTER_API_KEY` environment variable; raises a readable exception if it's missing
   - exponential-backoff retry on 429/529, up to 3 times; returns the raw JSON
2. `tools/jev/questions.py`
   - `JUDGE_QUESTIONS`: a dict of the 7 judgment questions above
   - `build_rank_question(candidates: list[str]) -> dict`: given 3 candidate replies, produces the `best_reply` question
   - `build_state(messages: list[tuple[str, str]], relationship: str) -> dict`
3. `tools/jev/fixtures/labeled_set.json`
   - **at least 25** Chinese conversation snippets, each shaped like:
     ```json
     {"id": "c01", "relationship": "...", "messages": [["her","..."],["me","..."]],
      "expect": {"true_intent": "confirm_you_care", "danger_level": 6, "she_needs": "action", "tension_resolved": false}}
     ```
   - write these snippets yourself, covering: a couple bickering, the other person clearly angry, the other person already satisfied, purely casual chat with no conflict, a coworker pushing for progress, friends making dinner plans, the other person being passive-aggressive, the other person issuing a flat-out ultimatum. **The danger level must cover the full 0-9 range**, not cluster in the middle.
   - `expect.danger_level` is a hand-labeled integer from 0-9
4. `tools/jev/calibrate.py`
   - runs the whole labeled set, serially (no concurrency, to avoid rate limits), sleeping 0.3s between items
   - outputs a table: hit rate per question, `danger_level`'s mean absolute error, average confidence, average latency, total cost
   - writes the item-by-item detail (including the diff between the model's answer and the human label) to `tools/jev/report/calibration.json` and a readable `tools/jev/report/calibration.md`
   - supports `--limit N` to run only the first N items, for easier debugging
5. `tools/jev/demo_meme.py`
   - run the full pipeline on the real conversation below (from the screenshot): the 7 judgment questions + ranking 3 candidate replies, and print the results. Write the 3 candidate replies yourself (one that deflects, one that apologizes, one that gives a concrete plan).
     ```
     her: Did you forget again what I told you today?
     me:  I remember, don't give me a hint, let me say it myself.
     her: Then say it.
     me:  Wait, I want to get it exactly right.
     her: You'd better.
     ```
   - expected: `true_intent` should land on "checking you care," `best_action` should be "check chat history," `danger_level` should be mid-to-high

## Acceptance (run it yourself and paste the **real output** into the report)

```
set OPENROUTER_API_KEY=<already in your environment>
python tools/jev/demo_meme.py
python tools/jev/calibrate.py
```

1. Both scripts exit with no exception, and every request returns HTTP 200
2. In `calibrate.py`'s output table: `danger_level`'s mean absolute error < 1.0 tier; `true_intent` and `she_needs` hit rate ≥ 60%
3. **If the first round doesn't hit the target, revise the question wording and option descriptions and rerun** (this is exactly the point of this task), up to 3 iterations, recording the number changes from each round in the report
4. Searching `tools/` for the OpenRouter key prefix must return no results (the key must not appear in any file)

## Hard rules

- No `git commit` / `git push`
- Only touch files under `tools/jev/`
- Python file I/O must always use explicit `encoding='utf-8'` (this machine is Chinese-locale Windows; the CP936 default would mangle text)
- Write Chinese output to files — don't rely on printing to the console coming out clean; add this at the top of scripts:
  `sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')`
- The key must never be written to any file

## Delivery

Write the report to `_reports/jev_questions_report.md`: approach → file list → the number changes across the three iterations → real acceptance-command output → **self-verification gaps** (which questions still feel unstable to you, which scenarios the labeled set under-covers).
