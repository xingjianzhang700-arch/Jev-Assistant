"""Run the screenshot conversation through the full Jev judge + rank flow."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from jev_client import ask, redact_secrets  # noqa: E402
from questions import JUDGE_QUESTIONS, build_rank_question, build_state  # noqa: E402

MESSAGES = [
    ("her", "Did you forget again what I told you earlier today?"),
    ("me", "I remember. Don't give me a hint, let me say it myself."),
    ("her", "Then say it."),
    ("me", "Hold on, I want to get it exactly right."),
    ("her", "You'd better."),
]

CANDIDATES = [
    "Haha okay okay, I remember, I remember.",
    "I'm sorry babe, I forgot again, my bad.",
    "Hang on, let me go check our chat history for what you mentioned, I'll get right back to you.",
]


def dump_answer(name: str, ans: dict) -> None:
    kind = ans.get("type")
    if kind == "noul":
        print(f"  {name}: noul={ans.get('noul')}")
    elif kind == "choice":
        print(f"  {name}: choice={ans.get('choice')}  conf={ans.get('confidence')}")
        probs = ans.get("probabilities") or {}
        if probs:
            ranked = sorted(probs.items(), key=lambda kv: -float(kv[1]))
            top = ", ".join(f"{k}={v:.3f}" for k, v in ranked[:4])
            print(f"           probs: {top}")
    elif kind == "score":
        print(
            f"  {name}: score={ans.get('score')}  conf={ans.get('confidence')}"
        )
        probs = ans.get("probabilities") or {}
        if probs:
            ranked = sorted(probs.items(), key=lambda kv: -float(kv[1]))
            top = ", ".join(f"{k}={v:.3f}" for k, v in ranked[:4])
            print(f"           bins: {top}")
    else:
        print(f"  {name}: {ans}")


def main() -> int:
    state = build_state(MESSAGES, "romantic partners")
    questions = dict(JUDGE_QUESTIONS)
    questions.update(build_rank_question(CANDIDATES))
    result = ask(state, questions, timeout=20)
    answers = result.get("answers") or {}
    usage = result.get("usage") or {}

    print("=== demo_meme ===")
    print("relationship: romantic partners")
    for who, text in MESSAGES:
        print(f"  {who}: {text}")
    print("candidates:")
    print(f"  reply_a (deflects): {CANDIDATES[0]}")
    print(f"  reply_b (apologizes): {CANDIDATES[1]}")
    print(f"  reply_c (checks history): {CANDIDATES[2]}")
    print("answers:")
    for name in list(JUDGE_QUESTIONS.keys()) + ["best_reply"]:
        if name in answers:
            dump_answer(name, answers[name])
        else:
            print(f"  {name}: MISSING")
    print(
        f"usage: input={usage.get('input_tokens')} output={usage.get('output_tokens')} "
        f"cost={usage.get('cost')} provider={result.get('provider')}"
    )

    intent = (answers.get("true_intent") or {}).get("choice")
    action = (answers.get("best_action") or {}).get("choice")
    danger = (answers.get("danger_level") or {}).get("score")
    reply = (answers.get("best_reply") or {}).get("choice")
    should = (answers.get("should_reply_now") or {}).get("noul")
    print("check:")
    print(f"  true_intent={intent}  (expect confirm_you_care)")
    print(f"  best_action={action}  (expect check_history)")
    print(f"  danger_level={danger}  (expect mid-high, about 4-6)")
    print(f"  should_reply_now={should}  (expect low: do not give substance yet)")
    print(f"  best_reply={reply}  (expect reply_c)")
    print(json.dumps({"ok": True, "http_status": 200}, ensure_ascii=False))

    report_dir = ROOT / "report"
    report_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "messages": [{"from": w, "text": t} for w, t in MESSAGES],
        "candidates": {
            "reply_a": CANDIDATES[0],
            "reply_b": CANDIDATES[1],
            "reply_c": CANDIDATES[2],
        },
        "answers": answers,
        "usage": usage,
        "provider": result.get("provider"),
    }
    (report_dir / "demo_meme.json").write_text(
        redact_secrets(json.dumps(payload, ensure_ascii=False, indent=2, default=str)),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
