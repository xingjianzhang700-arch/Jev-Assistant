#!/usr/bin/env python3
"""List tracked lines that still contain Chinese ideographs.

Usage: python3 tools/check_cjk.py [git pathspec ...]
Exit 1 if any non-allowlisted line is found, else 0.

Allowlisted:
- files whose Chinese is data we must not change (calibrated prompts,
  calibration fixtures, the bilingual legal NOTICE);
- any line ending in the marker `cjk-ok` (matchers for another app's
  Chinese UI, e.g. WeChat's "昨天").
"""
import re
import subprocess
import sys

CJK = re.compile(r"[㐀-䶿一-鿿]")
ALLOW_FILES = {
    "NOTICE",
    "app/src/main/java/com/jev/probe/jev/JevQuestions.kt",
    "tools/jev/questions.py",
    "tools/jev/fixtures/labeled_set.json",
    "tools/check_cjk.py",
    "docs/superpowers/plans/2026-09-22-english-instagram-sms.md",
    "shared/jev-brain.json",
    "extension/brain.json",
    "mac/Sources/JevCore/Brain.generated.swift",
}
MARK = "cjk-ok"


def main(argv):
    files = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", *argv],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    bad = 0
    for path in files:
        if path in ALLOW_FILES:
            continue
        try:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
        except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
            continue  # binary (png/apk/jar) or gone
        for n, line in enumerate(lines, 1):
            if CJK.search(line) and not line.rstrip().endswith(MARK):
                print(f"{path}:{n}: {line.strip()[:120]}")
                bad += 1
    print(f"{bad} line(s) with Chinese text", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
