#!/usr/bin/env python3
"""Render docs/demo.mp4 + docs/demo.gif to match the real Mac Jev panel UI.

Fictional boy-tries-to-rizz-girl thread. Two Analyze beats. Smooth scroll.
~15s at 12 fps. No real names / real chat text.
"""
from __future__ import annotations

import math
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT_MP4 = ROOT / "docs" / "demo.mp4"
OUT_GIF = ROOT / "docs" / "demo.gif"

W, H = 1100, 620
FPS = 12
DURATION = 15.0  # seconds
N = int(DURATION * FPS)

# Layout: Messages left, Jev panel right (matches live screenshot geometry).
MSG_X0, MSG_X1 = 24, 640
PANEL_X0, PANEL_X1 = 660, 1076
BG = "#1a1b1e"
MSG_BG = "#0e0e10"
PANEL_BG = "#2c2d30"
PANEL_CARD = "#3a3b40"
BLUE = "#0a84ff"
GRAY = "#3a3a3c"
INK = "#e8edf2"
MUTED = "#8b97a6"
GREEN = "#40c463"
CYAN = "#2dd4bf"
TITLE = "#e8edf2"


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    cands = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSText.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    if bold:
        cands = [
            "/System/Library/Fonts/SFNS.ttf",
            "/Library/Fonts/Arial Bold.ttf",
        ] + cands
    for p in cands:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded(d: ImageDraw.ImageDraw, box, r: int, fill, outline=None, width: int = 1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt, max_w: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [""]


# Beat timeline (seconds)
# 0.0–1.0: open thread
# 1.0–4.5: messages arrive (scroll), first Analyze
# 4.5–7.5: panel holds first result
# 7.5–11.0: second beat messages + Analyze again
# 11.0–15.0: second panel result

MSG1 = [
    ("me", "be honest. are you a parking ticket"),
    ("her", "sir. it is tuesday."),
    ("me", "because you've got FINE written all over you"),
    ("her", "I already said no to gym."),
]

MSG2_EXTRA = [
    ("me", "ok wait that was bad. brunch instead?"),
    ("her", "…maybe. text me a real plan."),
]

PANEL1 = {
    "risk": 2,
    "moods": [("Angry", 70), ("Furious", 20), ("Frustrated", 10)],
    "intent": "close the topic",
    "needs": "Needs (nothing) · make a plan · Hold off on specifics",
    "tension": True,
    "replies": [
        (0.51, "Got it. Want me to snag both our tickets tomorrow? We can settle up after."),
        (0.44, "Sweet, thanks for the info. I'll grab mine soon. You heading home after the gym?"),
        (0.05, "Cool cool. Good workout?"),
    ],
}

PANEL2 = {
    "risk": 1,
    "moods": [("Warm", 48), ("Playful", 32), ("Neutral", 20)],
    "intent": "open to a plan",
    "needs": "Needs a plan · acknowledge · OK to give specifics",
    "tension": True,
    "replies": [
        (0.62, "Sat 11, that bakery by the park. I'll grab a table."),
        (0.28, "Deal — I'll send two options tonight, you veto one."),
        (0.10, "Real plan incoming. Coffee or actual food?"),
    ],
}


def ease(t: float) -> float:
    return 0.5 - 0.5 * math.cos(min(max(t, 0.0), 1.0) * math.pi)


def visible_messages(t: float) -> tuple[list[tuple[str, str]], float]:
    """Return (messages, scroll_offset_px). Messages grow; older ones scroll up."""
    msgs: list[tuple[str, str]] = []
    # First four arrive over 0.8–3.2s
    for i, m in enumerate(MSG1):
        if t >= 0.6 + i * 0.55:
            msgs.append(m)
    # Second beat after first panel
    if t >= 8.0:
        msgs.append(MSG2_EXTRA[0])
    if t >= 9.0:
        msgs.append(MSG2_EXTRA[1])
    # Scroll so newest stay near bottom of the transcript viewport.
    viewport_h = 480
    # Approximate content height
    line_h = 56
    content = max(len(msgs) * line_h, viewport_h)
    # Target: bottom-align
    target = max(0, content - viewport_h)
    # Smooth toward target
    scroll = target * ease(min(1.0, (t - 0.5) / 3.0 if t < 8 else 1.0))
    if t >= 8.0:
        scroll = target  # stick to bottom for second beat
    return msgs, scroll


def draw_messages(img: Image.Image, msgs: list[tuple[str, str]], scroll: float, t: float):
    d = ImageDraw.Draw(img)
    # Messages window chrome
    rounded(d, (MSG_X0, 20, MSG_X1, H - 20), 14, MSG_BG, outline="#2a2a2e", width=1)
    d.text((MSG_X0 + 20, 36), "Messages · Maya", fill=TITLE, font=load_font(15, True))
    # Transcript clip region
    top, bottom = 70, H - 70
    transcript = Image.new("RGBA", (MSG_X1 - MSG_X0 - 16, bottom - top), (0, 0, 0, 0))
    td = ImageDraw.Draw(transcript)
    f = load_font(14)
    y = 12 - int(scroll)
    tw = transcript.size[0]
    for who, text in msgs:
        lines = wrap(td, text, f, 280)
        bh = 12 + len(lines) * 18
        bw = int(max(td.textlength(ln, font=f) for ln in lines) + 28)
        bw = min(bw, 320)
        if who == "me":
            x1 = tw - 16
            x0 = x1 - bw
            fill = BLUE
        else:
            x0 = 16
            x1 = x0 + bw
            fill = GRAY
        rounded(td, (x0, y, x1, y + bh), 14, fill)
        ty = y + 8
        for ln in lines:
            td.text((x0 + 14, ty), ln, fill="#ffffff", font=f)
            ty += 18
        y += bh + 12
    img.paste(transcript, (MSG_X0 + 8, top), transcript)
    # Composer hint
    d.text((MSG_X0 + 24, H - 52), "iMessage", fill=MUTED, font=load_font(12))


def draw_panel(img: Image.Image, panel: dict | None, title: str, opacity: float):
    if panel is None or opacity <= 0.01:
        return
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    x0, x1 = PANEL_X0, PANEL_X1
    y0, y1 = 28, H - 28
    # Fade via alpha on a solid panel
    panel_img = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel_img)
    rounded(pd, (0, 0, x1 - x0 - 1, y1 - y0 - 1), 12, PANEL_BG, outline="#4a4b50", width=1)
    # traffic lights
    pd.ellipse((12, 12, 24, 24), fill="#ff5f57")
    pd.ellipse((30, 12, 42, 24), fill="#febc2e")
    pd.ellipse((48, 12, 60, 24), fill="#28c840")
    pd.text((72, 10), f"Jev · {title}", fill=TITLE, font=load_font(13, True))

    y = 44
    pd.text((16, y), f"Risk {panel['risk']} / 9", fill=GREEN, font=load_font(16, True))
    y += 28
    # Spaced moods — separate chips with ≥16px gaps
    mx = 16
    pd.text((mx, y), "Mood:", fill=INK, font=load_font(13, True))
    mx += int(pd.textlength("Mood:", font=load_font(13, True))) + 16
    for name, pct in panel["moods"]:
        chip = f"{name} {pct}%"
        pd.text((mx, y), chip, fill=INK, font=load_font(13, True))
        mx += int(pd.textlength(chip, font=load_font(13, True))) + 16
    y += 26
    pd.text((16, y), f"Their real intent: {panel['intent']}", fill=INK, font=load_font(13, True))
    y += 22
    pd.text((16, y), panel["needs"], fill=MUTED, font=load_font(11))
    y += 20
    if panel.get("tension"):
        pd.text((16, y), "✓ Tension resolved", fill=GREEN, font=load_font(12))
        y += 22
    pd.text((16, y), "Suggested replies", fill=MUTED, font=load_font(11))
    y += 18
    f_body = load_font(12)
    for prob, text in panel["replies"]:
        card_h = 78
        rounded(pd, (12, y, x1 - x0 - 12, y + card_h), 10, PANEL_CARD, outline="#55565c", width=1)
        pd.text((22, y + 8), f"{int(prob * 100)}%", fill=CYAN, font=load_font(13, True))
        lines = wrap(pd, text, f_body, x1 - x0 - 50)
        ty = y + 28
        for ln in lines[:2]:
            pd.text((22, ty), ln, fill=INK, font=f_body)
            ty += 16
        # Fill / Copy affordances
        rounded(pd, (22, y + card_h - 26, 62, y + card_h - 8), 5, "#4a4b50")
        pd.text((28, y + card_h - 24), "Fill", fill=INK, font=load_font(10))
        rounded(pd, (70, y + card_h - 26, 118, y + card_h - 8), 5, "#4a4b50")
        pd.text((76, y + card_h - 24), "Copy", fill=INK, font=load_font(10))
        y += card_h + 8

    # Apply opacity
    if opacity < 0.999:
        a = panel_img.split()[-1].point(lambda p: int(p * opacity))
        panel_img.putalpha(a)
    overlay.paste(panel_img, (x0, y0), panel_img)
    img.alpha_composite(overlay)


def panel_for_time(t: float) -> tuple[dict | None, str, float]:
    # First analyze ~3.8–7.2
    if 3.6 <= t < 7.8:
        op = ease((t - 3.6) / 0.4) if t < 4.2 else 1.0
        if t >= 7.4:
            op = 1.0 - ease((t - 7.4) / 0.4)
        return PANEL1, "Maya", op
    # Second analyze ~10.2–15
    if t >= 10.0:
        op = ease((t - 10.0) / 0.4) if t < 10.6 else 1.0
        return PANEL2, "Maya", op
    return None, "Maya", 0.0


def frame(t: float) -> Image.Image:
    img = Image.new("RGBA", (W, H), BG)
    msgs, scroll = visible_messages(t)
    draw_messages(img, msgs, scroll, t)
    panel, title, op = panel_for_time(t)
    draw_panel(img, panel, title, op)
    # Caption strip
    d = ImageDraw.Draw(img)
    if t < 3.5:
        cap = "He tries a line. She is not impressed."
    elif t < 7.8:
        cap = "Analyze #1 — Jev ranks safer replies."
    elif t < 10.0:
        cap = "He course-corrects. She softens."
    else:
        cap = "Analyze #2 — new mood, new plan."
    d.text((MSG_X0 + 8, H - 28), cap, fill=MUTED, font=load_font(12))
    return img.convert("RGB")


def main() -> None:
    ROOT.joinpath("docs").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tdir = Path(td)
        frames: list[Image.Image] = []
        for i in range(N):
            t = i / FPS
            im = frame(t)
            path = tdir / f"f{i:04d}.png"
            im.save(path)
            frames.append(im)
            if i % 24 == 0:
                print(f"frame {i}/{N}")
        # GIF (smaller palette)
        frames[0].save(
            OUT_GIF,
            save_all=True,
            append_images=frames[1:],
            duration=int(1000 / FPS),
            loop=0,
            optimize=True,
        )
        # MP4 via ffmpeg
        pattern = str(tdir / "f%04d.png")
        subprocess.run(
            [
                "ffmpeg", "-y", "-framerate", str(FPS), "-i", pattern,
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
                str(OUT_MP4),
            ],
            check=True,
            capture_output=True,
        )
    print(f"wrote {OUT_GIF} and {OUT_MP4} ({DURATION}s @ {FPS}fps, {N} frames)")


if __name__ == "__main__":
    main()
