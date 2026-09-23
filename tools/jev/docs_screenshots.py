"""Build fictional README guidance screenshots under docs/images/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "images"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSText.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    if bold:
        candidates = [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/Library/Fonts/Arial Bold.ttf",
        ] + candidates
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded(draw: ImageDraw.ImageDraw, box, radius: int, fill, outline=None, width: int = 1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def mac_judge_key() -> None:
    """Fake Mac dialog: where the Judge API key is pasted (fictional key only)."""
    w, h = 560, 280
    img = Image.new("RGB", (w, h), "#eceff3")
    d = ImageDraw.Draw(img)
    # Window chrome
    rounded(d, (40, 36, w - 40, h - 36), 14, "#f7f8fa", outline="#c5cad3", width=1)
    d.ellipse((58, 52, 72, 66), fill="#ff5f57")
    d.ellipse((80, 52, 94, 66), fill="#febc2e")
    d.ellipse((102, 52, 116, 66), fill="#28c840")
    d.text((140, 50), "Jev · Set Judge API key", fill="#1c1f24", font=font(15, True))
    d.text((58, 92), "Paste your OpenRouter key. It stays on this Mac.", fill="#5b6572", font=font(13))
    rounded(d, (58, 124, w - 58, 168), 8, "#ffffff", outline="#b8bfc9", width=1)
    # Fictional placeholder — never a real key
    d.text((70, 136), "sk-or-v1-························", fill="#6b7280", font=font(14))
    rounded(d, (w - 168, h - 86, w - 58, h - 54), 8, "#1c5c58")
    d.text((w - 148, h - 78), "Save", fill="#e8edf2", font=font(14, True))
    rounded(d, (w - 268, h - 86, w - 180, h - 54), 8, "#ffffff", outline="#b8bfc9", width=1)
    d.text((w - 252, h - 78), "Cancel", fill="#374151", font=font(14))
    img.save(OUT / "mac-judge-key.png", optimize=True)


def extension_judge_key() -> None:
    """Fake extension options page highlighting Judge API key field."""
    w, h = 640, 420
    img = Image.new("RGB", (w, h), "#0e1116")
    d = ImageDraw.Draw(img)
    rounded(d, (36, 28, w - 36, h - 28), 16, "#171c24", outline="#2a323e", width=1)
    d.text((60, 52), "Jev Assistant", fill="#e8edf2", font=font(22, True))
    d.text((60, 96), "Judge API key (OpenRouter)", fill="#8b97a6", font=font(14))
    rounded(d, (60, 122, w - 60, 166), 10, "#0e1116", outline="#3ee0d2", width=2)
    d.text((76, 134), "sk-or-v1-························", fill="#8b97a6", font=font(15))
    # Callout
    d.text((60, 180), "← Paste the key here, then Save. Leave Reply empty to reuse it.", fill="#3ee0d2", font=font(13))
    d.text((60, 220), "Reply API key (optional)", fill="#8b97a6", font=font(14))
    rounded(d, (60, 246, w - 60, 290), 10, "#0e1116", outline="#2a323e", width=1)
    d.text((76, 258), "(empty — reuses Judge)", fill="#5b6572", font=font(14))
    rounded(d, (60, 320, 160, 358), 10, "#1c5c58")
    d.text((86, 330), "Save", fill="#e8edf2", font=font(15, True))
    img.save(OUT / "extension-judge-key.png", optimize=True)


def browser_paste_page() -> None:
    """Recreate docs/use.html after a fictional analyze: key field + spaced moods + replies."""
    w, h = 720, 780
    img = Image.new("RGB", (w, h), "#0e1116")
    d = ImageDraw.Draw(img)
    x0, y = 48, 36
    d.text((x0, y), "Jev", fill="#3ee0d2", font=font(28, True))
    d.text((x0 + 62, y), "Assistant", fill="#e8edf2", font=font(28, True))
    y += 44
    d.text((x0, y), "Paste a chat. Jev reads her mood as a percent and suggests three replies.", fill="#8b97a6", font=font(14))
    y += 40
    d.text((x0, y), "OpenRouter API key", fill="#c5cad3", font=font(14))
    y += 26
    rounded(d, (x0, y, w - x0, y + 44), 12, "#171c24", outline="#2a323e", width=1)
    d.text((x0 + 14, y + 12), "sk-or-v1-························", fill="#8b97a6", font=font(15))
    y += 64
    d.text((x0, y), "Chat", fill="#c5cad3", font=font(14))
    y += 26
    rounded(d, (x0, y, w - x0, y + 120), 12, "#171c24", outline="#2a323e", width=1)
    chat = [
        "Me: be honest. are you a parking ticket",
        "Her: sir. it is tuesday.",
        "Me: so… gym later?",
        "Her: I already said no.",
    ]
    cy = y + 14
    for line in chat:
        d.text((x0 + 14, cy), line, fill="#e8edf2", font=font(14))
        cy += 22
    y += 140
    rounded(d, (x0, y, w - x0, y + 48), 12, "#1c5c58")
    d.text((w // 2 - 36, y + 14), "Analyze", fill="#e8edf2", font=font(16, True))
    y += 68
    # Mood card with ≥16px gaps between separate mood chips (never one clutched string).
    rounded(d, (x0, y, w - x0, y + 56), 14, "#171c24", outline="#2a323e", width=1)
    moods = [("Mood:", "#8b97a6"), ("Angry 70%", "#e8edf2"), ("Furious 20%", "#e8edf2"), ("Frustrated 10%", "#e8edf2")]
    mx = x0 + 16
    gap = 24
    for text, color in moods:
        d.text((mx, y + 16), text, fill=color, font=font(15, True))
        mx += d.textlength(text, font=font(15, True)) + gap
    y += 72
    replies = [
        "Got it. Want me to snag both our tickets tomorrow?",
        "Sweet, thanks for the info. I'll grab mine soon.",
        "Cool cool. Good workout?",
    ]
    for text in replies:
        rounded(d, (x0, y, w - x0, y + 52), 14, "#171c24", outline="#2a323e", width=1)
        d.text((x0 + 16, y + 16), text, fill="#e8edf2", font=font(14))
        rounded(d, (w - x0 - 78, y + 12, w - x0 - 14, y + 40), 8, "#1c5c58")
        d.text((w - x0 - 66, y + 18), "Copy", fill="#e8edf2", font=font(13, True))
        y += 64
    img.save(OUT / "browser-paste-analyze.png", optimize=True)


def panel_fallback() -> None:
    """Pillow stand-in if Mac --preview PNG capture is unavailable."""
    w, h = 400, 420
    img = Image.new("RGB", (w, h), "#f5f6f8")
    d = ImageDraw.Draw(img)
    rounded(d, (12, 12, w - 12, h - 12), 12, "#ffffff", outline="#d1d5db", width=1)
    d.text((28, 28), "Jev · Alex", fill="#111827", font=font(15, True))
    d.text((28, 58), "Risk 2 / 9", fill="#16a34a", font=font(16, True))
    # Separate chips with ≥16pt gaps; wrap the third mood rather than clutch.
    chips = ["Mood:", "Angry 70%", "Furious 20%", "Frustrated 10%"]
    mx, my, gap = 28, 88, 16
    for i, m in enumerate(chips):
        tw = int(d.textlength(m, font=font(14, True)))
        if i > 0 and mx + tw > w - 28:
            mx, my = 28, my + 22
        d.text((mx, my), m, fill="#111827", font=font(14, True))
        mx += tw + gap
    d.text((28, my + 30), "Their real intent: Close the topic", fill="#111827", font=font(14, True))
    d.text((28, my + 60), "Suggested replies", fill="#6b7280", font=font(12))
    replies = [
        ("51%", "Got it. Want me to snag both our tickets tomorrow? We can settle up after."),
        ("44%", "Sweet, thanks for the info. I'll grab mine soon. You heading home after the gym?"),
        ("5%", "Cool cool. Good workout?"),
    ]
    y = my + 84
    for pct, text in replies:
        rounded(d, (24, y, w - 24, y + 70), 10, "#f3f4f6", outline="#e5e7eb", width=1)
        d.text((36, y + 8), pct, fill="#2dd4bf", font=font(13, True))
        words, line, lines = text.split(), "", []
        for word in words:
            trial = (line + " " + word).strip()
            if d.textlength(trial, font=font(12)) > w - 80:
                lines.append(line)
                line = word
            else:
                line = trial
        if line:
            lines.append(line)
        ty = y + 28
        for ln in lines[:2]:
            d.text((36, ty), ln, fill="#111827", font=font(12))
            ty += 16
        y += 78
    img.save(OUT / "mac-panel-moods.png", optimize=True)


def chrome_extensions() -> None:
    """Fictional chrome://extensions with Developer mode on and Load unpacked called out."""
    w, h = 960, 520
    img = Image.new("RGB", (w, h), "#202124")
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 220, h), fill="#292a2d")
    d.text((24, 28), "Extensions", fill="#e8eaed", font=font(22, True))
    d.text((24, 80), "My extensions", fill="#e8eaed", font=font(14, True))
    d.text((24, 112), "Site permissions", fill="#9aa0a6", font=font(14))
    d.text((24, 144), "Keyboard shortcuts", fill="#9aa0a6", font=font(14))
    d.text((250, 28), "Extensions", fill="#e8eaed", font=font(20, True))
    d.text((w - 210, 32), "Developer mode", fill="#e8eaed", font=font(13))
    rounded(d, (w - 70, 30, w - 30, 52), 11, "#8ab4f8")
    d.ellipse((w - 52, 32, w - 32, 50), fill="#ffffff")
    rounded(d, (250, 72, 390, 108), 8, "#3c4043")
    d.text((268, 82), "Load unpacked", fill="#e8eaed", font=font(14, True))
    rounded(d, (250, 140, w - 40, 280), 12, "#292a2d", outline="#3c4043", width=1)
    d.text((270, 160), "Jev Assistant", fill="#e8eaed", font=font(18, True))
    d.text((270, 196), "extension/  ·  Unpacked", fill="#9aa0a6", font=font(13))
    d.text((270, 228), "Reads WhatsApp Web, Instagram Direct, Snapchat Web, Google Messages.", fill="#9aa0a6", font=font(13))
    d.text((250, 310), "1. Turn on Developer mode → 2. Load unpacked → 3. Pick the extension/ folder.", fill="#8ab4f8", font=font(13))
    img.save(OUT / "chrome-extensions.png", optimize=True)


def firefox_temp_addon() -> None:
    """Fictional about:debugging Load Temporary Add-on callout."""
    w, h = 880, 420
    img = Image.new("RGB", (w, h), "#1c1b22")
    d = ImageDraw.Draw(img)
    d.text((36, 28), "This Firefox", fill="#fbfbfe", font=font(22, True))
    d.text((36, 68), "Temporary Extensions", fill="#cfcfd8", font=font(15))
    rounded(d, (36, 110, 280, 152), 10, "#0060df")
    d.text((52, 122), "Load Temporary Add-on…", fill="#ffffff", font=font(14, True))
    rounded(d, (36, 180, w - 36, 300), 12, "#2b2a33", outline="#52525e", width=1)
    d.text((56, 200), "Jev Assistant", fill="#fbfbfe", font=font(17, True))
    d.text((56, 236), "Temporary · extension/manifest.json", fill="#cfcfd8", font=font(13))
    d.text((56, 268), "Removed when Firefox quits — load that file again after a restart.", fill="#cfcfd8", font=font(13))
    d.text((36, 340), "about:debugging#/runtime/this-firefox → Load Temporary Add-on… → manifest.json", fill="#00ddff", font=font(13))
    img.save(OUT / "firefox-temp-addon.png", optimize=True)


def mac_set_relationship() -> None:
    """Fictional Mac dialog for Jev → Set relationship… (no real contact names)."""
    w, h = 560, 300
    img = Image.new("RGB", (w, h), "#eceff3")
    d = ImageDraw.Draw(img)
    rounded(d, (40, 36, w - 40, h - 36), 14, "#f7f8fa", outline="#c5cad3", width=1)
    d.ellipse((58, 52, 72, 66), fill="#ff5f57")
    d.ellipse((80, 52, 94, 66), fill="#febc2e")
    d.ellipse((102, 52, 116, 66), fill="#28c840")
    d.text((140, 50), "Jev · Set relationship", fill="#1c1f24", font=font(15, True))
    d.text((58, 88), "Who is the other person to you?", fill="#5b6572", font=font(13))
    rounded(d, (58, 118, w - 58, 190), 8, "#ffffff", outline="#b8bfc9", width=1)
    d.text((70, 132), "A classmate I study with; from=me is what I sent,", fill="#374151", font=font(13))
    d.text((70, 154), "from=other is what they sent.", fill="#374151", font=font(13))
    rounded(d, (w - 168, h - 86, w - 58, h - 54), 8, "#1c5c58")
    d.text((w - 148, h - 78), "Save", fill="#e8edf2", font=font(14, True))
    rounded(d, (w - 268, h - 86, w - 180, h - 54), 8, "#ffffff", outline="#b8bfc9", width=1)
    d.text((w - 252, h - 78), "Cancel", fill="#374151", font=font(14))
    img.save(OUT / "mac-set-relationship.png", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    mac_judge_key()
    extension_judge_key()
    browser_paste_page()
    panel_fallback()
    chrome_extensions()
    firefox_temp_addon()
    mac_set_relationship()
    print("wrote", OUT / "mac-judge-key.png")
    print("wrote", OUT / "extension-judge-key.png")
    print("wrote", OUT / "browser-paste-analyze.png")
    print("wrote", OUT / "mac-panel-moods.png")
    print("wrote", OUT / "chrome-extensions.png")
    print("wrote", OUT / "firefox-temp-addon.png")
    print("wrote", OUT / "mac-set-relationship.png")


if __name__ == "__main__":
    main()
