#!/usr/bin/env python3
"""Stacks the boot test screenshots into one tall JPEG with captions.

A single image opens straight in a phone browser (the workflow uploads it
unzipped), so the look of a build can be checked without a PC.

Usage: tests/screenshot-sheet.py <screenshot dir> <output.jpg> [title]
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

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
    "terminal": "Terminal: prompt and fastfetch (ff)",
    "terminal-zoom": "Terminal, full size",
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


def caption_key(stem):
    return stem.split("-", 1)[1] if stem[:2].isdigit() else stem


def caption(stem):
    key = caption_key(stem)
    return CAPTIONS.get(key, key.replace("-", " ").capitalize())


def runs(counts, threshold, gap):
    """Groups the indices whose count reaches threshold, joining groups less
    than gap apart; returns the widest group as (first, last) or None."""
    groups = []
    for i, count in enumerate(counts):
        if count < threshold:
            continue
        if groups and i - groups[-1][1] <= gap:
            groups[-1][1] = i
        else:
            groups.append([i, i])
    return max(groups, key=lambda g: g[1] - g[0], default=None)


def terminal_zoom(src):
    """Crops the terminal window out of the terminal screenshot, at full size,
    so its text and symbols can be checked: the window is where the
    screenshot differs from the desktop one taken before it. Returns the path
    of the crop (<terminal screenshot>-zoom.png) or None."""
    shots = {caption_key(p.stem): p for p in src.iterdir() if p.suffix in (".png", ".ppm")}
    if "terminal" not in shots or "desktop" not in shots:
        return None
    terminal = Image.open(shots["terminal"]).convert("RGB")
    desktop = Image.open(shots["desktop"]).convert("RGB")
    if terminal.size != desktop.size:
        return None
    # Changed pixels per column and row; the clock and the dock change too,
    # but on far fewer pixels than a window
    diff = ImageChops.difference(terminal, desktop).convert("L").point(lambda v: 255 if v > 6 else 0)
    width, height = diff.size

    def counts(img):
        data, size = img.tobytes(), img.width
        return [data.count(255, i * size, (i + 1) * size) for i in range(img.height)]

    rows, cols = counts(diff), counts(diff.transpose(Image.Transpose.TRANSPOSE))
    x_run = runs(cols, height // 10, 80)
    y_run = runs(rows, width // 10, 80)
    if not x_run or not y_run:
        return None
    (left, right), (top, bottom) = x_run, y_run
    if right - left < 300 or bottom - top < 200:
        return None
    pad = 6
    box = (max(left - pad, 0), max(top - pad, 0), min(right + pad + 1, width), min(bottom + pad + 1, height))
    out = shots["terminal"].with_name(shots["terminal"].stem + "-zoom.png")
    terminal.crop(box).save(out)
    return out


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    title = sys.argv[3] if len(sys.argv) > 3 else "cosmic-blue"
    try:
        zoom = terminal_zoom(src)
        if zoom:
            print(f"{zoom}: terminal window")
    except Exception as error:  # a missing crop must not lose the sheet
        print(f"No terminal crop: {error}")
    files = sorted(p for p in src.iterdir() if p.suffix in (".png", ".ppm"))
    if not files:
        sys.exit(f"No screenshots in {src}")

    title_font, caption_font = font(44), font(30)
    title_h, caption_h = 90, 56
    shots = []
    for path in files:
        img = Image.open(path).convert("RGB")
        if img.width > WIDTH or not path.stem.endswith("-zoom"):
            # Crops are shown at full size when they fit
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
