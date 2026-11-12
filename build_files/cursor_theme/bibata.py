#!/usr/bin/python3
"""Build Bibata Modern as an X cursor theme, recolored for cosmic-blue.

Usage: bibata.py SOURCE_DIR OUTPUT_DIR VERSION

SOURCE_DIR is a checkout of https://github.com/ful1e5/Bibata_Cursor. Its SVGs
use placeholder colors (see its render.json), replaced here by ours; its
configs/normal/x.build.toml gives the sizes, hotspots, frame delays and alias
names of each cursor. Upstream renders the SVGs with cbmp (Node.js and a
headless browser) and builds the cursors with clickgen (ctgen); rsvg-convert
and xcursorgen do the same job with Fedora packages, rendering each size from
the SVG instead of scaling down one bitmap.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

# Placeholder colors of the Bibata SVGs -> cosmic-blue colors.
# Body: the deep night blue of the wallpaper. Outline: white, for contrast on
# dark and light surfaces alike. Wait spinner ring: the dark accent of
# build_files/theme/src/main.rs.
COLORS = {
    "#00FF00": "#0B1736",  # body
    "#0000FF": "#FFFFFF",  # outline
    "#FF0000": "#4F8DFF",  # wait spinner
}
NAME = "Bibata Modern cosmic-blue"
CANVAS = 256  # size of the Bibata SVGs, the unit of the hotspots


def recolor(svg: str) -> str:
    for placeholder, color in COLORS.items():
        svg = svg.replace(placeholder, color).replace(placeholder.lower(), color)
    return svg


def main() -> None:
    src, out, version = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    config = tomllib.loads((src / "configs/normal/x.build.toml").read_text())
    cursors = config["cursors"]
    defaults = cursors.pop("fallback_settings")

    # Bitmap name (as in the config) -> SVG. Animated cursors are folders of
    # numbered frames (wait/wait-01.svg...), the others are links to shared
    # drawings: resolve both.
    svgs = {
        Path(name).stem: (Path(root) / name).resolve()
        for root, _, files in os.walk(src / "svg/modern", followlinks=True)
        for name in files
        if name.endswith(".svg")
    }

    if out.exists():
        shutil.rmtree(out)
    (out / "cursors").mkdir(parents=True)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for key, cursor in cursors.items():
            pattern = cursor["png"].removesuffix(".png")
            if "*" in pattern:
                prefix = pattern.removesuffix("*")
                frames = sorted(n for n in svgs if n.startswith(prefix) and n[len(prefix):].isdigit())
            else:
                frames = [pattern]
            if not frames or any(f not in svgs for f in frames):
                sys.exit(f"{key}: no SVG for {cursor['png']}")

            sizes = cursor.get("x11_sizes", defaults["x11_sizes"])
            x_hot = cursor.get("x_hotspot", defaults["x_hotspot"])
            y_hot = cursor.get("y_hotspot", defaults["y_hotspot"])
            delay = cursor.get("x11_delay", defaults["x11_delay"])

            lines = []
            for frame in frames:
                recolored = tmp / f"{frame}.svg"
                recolored.write_text(recolor(svgs[frame].read_text()))
                for size in sizes:
                    png = tmp / f"{frame}-{size}.png"
                    subprocess.run(
                        ["rsvg-convert", "-w", str(size), "-h", str(size), "-o", png, recolored],
                        check=True,
                    )
                    x = min(size - 1, round(x_hot * size / CANVAS))
                    y = min(size - 1, round(y_hot * size / CANVAS))
                    lines.append(f"{size} {x} {y} {png}" + (f" {delay}" if len(frames) > 1 else ""))

            name = cursor["x11_name"]
            cfg = tmp / f"{name}.cfg"
            cfg.write_text("\n".join(lines) + "\n")
            subprocess.run(["xcursorgen", cfg, out / "cursors" / name], check=True)
            for alias in cursor.get("x11_symlinks", []):
                link = out / "cursors" / alias
                if not link.exists():
                    os.symlink(name, link)

    (out / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name={NAME}\n"
        f"Comment=Bibata Modern {version} by Abdulkaiz Khatri, in the cosmic-blue colors\n"
    )
    shutil.copy(src / "LICENSE", out / "LICENSE")

    # The shapes every desktop asks for must be there
    for name in ("default", "left_ptr", "pointer", "text", "xterm", "wait", "progress",
                 "grabbing", "not-allowed", "nwse-resize", "col-resize"):
        if not (out / "cursors" / name).exists():
            sys.exit(f"missing cursor: {name}")


if __name__ == "__main__":
    main()
