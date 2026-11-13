#!/usr/bin/env python3
"""Stacks the boot test screenshots into one tall JPEG with captions.

A single image opens straight in a phone browser (the workflow uploads it
unzipped), so the look of a build can be checked without a PC.

Usage: tests/screenshot-sheet.py <screenshot dir> <output.jpg> [title]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CAPTIONS = {
    "before-update": "Before the update: desktop of the previous image",
    "login-failed-before-update": "Before the update: login failed",
    "login-screen": "Login screen",
    "login-failed": "Login failed",
    "first-run": "First login: welcome assistant",
    "desktop": "Desktop, panel and dock",
    "app-library": "App Library (icons)",
    "files": "Files (folder icons)",
    "settings": "Settings: Appearance",
    "terminal": "Terminal",
    "lock-screen": "Lock screen",
}
WIDTH = 1280
MARGIN = 24
BACKGROUND = (12, 18, 38)
TEXT = (230, 236, 255)
ACCENT = (79, 141, 255)  # #4f8dff, the cosmic-blue accent


def font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def caption(stem):
    key = stem.split("-", 1)[1] if stem[:2].isdigit() else stem
    return CAPTIONS.get(key, key.replace("-", " ").capitalize())


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    title = sys.argv[3] if len(sys.argv) > 3 else "cosmic-blue"
    files = sorted(p for p in src.iterdir() if p.suffix in (".png", ".ppm"))
    if not files:
        sys.exit(f"No screenshots in {src}")

    title_font, caption_font = font(44), font(30)
    title_h, caption_h = 90, 56
    shots = []
    for path in files:
        img = Image.open(path).convert("RGB")
        img = img.resize((WIDTH, round(img.height * WIDTH / img.width)), Image.LANCZOS)
        shots.append((caption(path.stem), img))

    height = title_h + sum(caption_h + img.height + MARGIN for _, img in shots) + MARGIN
    sheet = Image.new("RGB", (WIDTH + 2 * MARGIN, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((MARGIN, 24), title, font=title_font, fill=ACCENT)
    y = title_h
    for text, img in shots:
        draw.text((MARGIN, y + 10), text, font=caption_font, fill=TEXT)
        y += caption_h
        sheet.paste(img, (MARGIN, y))
        y += img.height + MARGIN
    sheet.save(out, "JPEG", quality=85, optimize=True)
    print(f"{out}: {len(shots)} screenshots")


if __name__ == "__main__":
    main()
