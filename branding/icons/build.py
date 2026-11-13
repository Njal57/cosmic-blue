#!/usr/bin/env python3
"""Generate the cosmic-blue icons drawn on top of Tela circle.

- places: folders (a planet-like disk in the logo blues, with a folder tab
  and the logo's moon), the home, desktop, network and trash icons
- mimetypes: common file types (a light page whose symbol and folded corner
  take the color of the type)
- apps: the live ISO's welcome tour and installer

The icon theme (build_files/icon_theme/compose.py) puts them in front of
Tela; every other icon still comes from Tela.

Usage: python3 build.py  (rewrites build_files/icon_theme/layer/)
"""
import os
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
LAYER = REPO / "build_files" / "icon_theme" / "layer"
APPS = REPO / "iso_files" / "welcome"

# Logo blues (branding/logo/build.py) and the accent (#4f8dff dark, #1d47c4 light)
ORBIT = ("#7fe0ff", "#2f6bff")
MOON = "#e6f3ff"


def stroke(d, width=2.2):
    return (f'<path d="{d}" fill="none" stroke="currentColor" stroke-width="{width}" '
            'stroke-linecap="round" stroke-linejoin="round"/>')


def fill(d):
    return f'<path d="{d}" fill="currentColor"/>'


def dot(x, y, r):
    return fill(f"M{x - r} {y}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0")


# Symbols drawn in a 24x24 box centered on 0,0, in currentColor
GLYPHS = {
    "documents": stroke("M-6 -9h8l4 4v14h-12z") + stroke("M-3 -1h6M-3 3h6M-3 7h4", 1.8),
    "download": stroke("M0 -9v13M-6 -2l6 6 6-6") + stroke("M-8 9h16"),
    "music": stroke("M-3 6v-13l10 -3v13") + dot(-3, 6, 3.6) + dot(7, 3, 3.6),
    "pictures": stroke("M-9 -7h18v14h-18z") + stroke("M-9 5l6-6 5 5 3-3 4 4", 2) + dot(4, -3.5, 2.2),
    "videos": stroke("M-9 -7h18v14h-18z") + fill("M-2.5 -4v8l7 -4z"),
    "desktop": stroke("M-10 -8h20v13h-20z") + stroke("M-4 9h8M0 5v4"),
    "home": stroke("M-9 0l9-8 9 8M-6 -2v10h12v-10") + fill("M-2 8v-5h4v5z"),
    "templates": stroke("M-8 -9h16v18h-16z") + stroke("M-4 -4h8M-4 0h8M-4 4h4", 1.8),
    "publicshare": dot(-6, 0, 3) + dot(6, -6, 3) + dot(6, 6, 3) + stroke("M-6 0l12-6M-6 0l12 6", 2),
    "network": stroke("M0 -9a9 9 0 1 0 0.01 0z")
    + stroke("M-9 0h18M0 -9c-4 4-4 14 0 18M0 -9c4 4 4 14 0 18", 1.8),
    "recent": stroke("M0 -9a9 9 0 1 0 0.01 0z") + stroke("M0 -5v5l4 3"),
    "trash": stroke("M-9 -6h18M-3 -6v-3h6v3M-7 -6l1.5 15h11l1.5-15") + stroke("M-2 -1v6M2 -1v6", 1.8),
    "trash-full": stroke("M-9 -4h18M-7 -4l1.5 13h11l1.5-13") + stroke("M-5 -7l3-4 3 3 3-3 3 4", 1.8)
    + stroke("M-2 1v4M2 1v4", 1.8),
    "text": stroke("M-6 -6h12M-6 -2h12M-6 2h12M-6 6h7", 2),
    "document": fill("M-7 -8h14v4h-14z") + stroke("M-6 1h12M-6 5h12M-6 9h8", 1.8),
    "spreadsheet": stroke("M-7 -7h14v15h-14zM-7 -2h14M-7 3h14M-1 -7v15", 1.8),
    "presentation": stroke("M-8 -7h16v11h-16z", 2) + stroke("M0 4v5M-4 9h8", 2)
    + fill("M-4 1v-4h2.5v4zM-0.5 1v-6h2.5v6zM3 1v-2.5h2.5v2.5z"),
    "pdf": stroke("M-7 7c3-1 6-6 7-12c0-3-2-3-2 0c0 3 3 9 9 10c2 0 2-2 0-2c-5 0-11 3-14 6c-1 1 0 2 1 1", 1.9),
    "image": stroke("M-9 7l6-7 4 4 3-3 5 6z", 2) + dot(4, -5, 2.6),
    "audio": stroke("M-3 6v-13l9 -2.5v13") + dot(-3, 6, 3.4) + dot(6, 3.5, 3.4),
    "video": fill("M-5 -8v16l13-8z"),
    "archive": fill("M-3 -11h3v2.5h-3zM0 -8.5h3v2.5h-3zM-3 -6h3v2.5h-3zM0 -3.5h3v2.5h-3z")
    + stroke("M-3.5 1h7v8h-7zM-3.5 5h7", 2),
    "script": stroke("M-7 -5l5 5-5 5M1 6h7", 2.4),
    "code": stroke("M-4 -6l-6 6 6 6M4 -6l6 6-6 6M2 -9l-4 18", 2.2),
    "font": stroke("M-8 9l8-18 8 18M-4.5 2h9", 2.4),
    "disc": stroke("M0 -9a9 9 0 1 0 0.01 0z") + dot(0, 0, 2.5),
    "package": stroke("M0 -9l8 4v10l-8 4-8-4v-10zM-8 -5l8 4 8-4M0 -1v10", 2),
    "unknown": stroke("M-4 -4a4 4 0 1 1 6 3.5c-1.5 1-2 2-2 3.5", 2.4) + dot(0, 8, 1.6),
}


def svg(body, defs=""):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
            f"<defs>{defs}</defs>{body}</svg>\n")


def glyph(name, x, y, scale, color):
    if not name:
        return ""
    return f'<g color="{color}" transform="translate({x} {y}) scale({scale})">{GLYPHS[name]}</g>'


# --- Folders -----------------------------------------------------------------

FOLDER_DEFS = (
    '<clipPath id="disk"><circle cx="32" cy="32" r="28"/></clipPath>'
    '<linearGradient id="front" x1=".15" y1="0" x2=".85" y2="1">'
    '<stop offset="0" stop-color="#78aeff"/><stop offset=".55" stop-color="#4f8dff"/>'
    '<stop offset="1" stop-color="#2f6bff"/></linearGradient>'
)


def folder(name, open_=False):
    """A disk: dark inside, the back panel with its tab, the lighter front panel.

    The front panel starts lower when the folder is open. The logo's moon sits
    on the bottom right edge.
    """
    front = 22.0 if open_ else 18.6
    body = (
        '<g clip-path="url(#disk)">'
        '<rect x="4" y="4" width="56" height="56" fill="#15338f"/>'
        '<path d="M4 11.3H29.2L33.1 15.2H60V60H4z" fill="#2f63d8"/>'
        f'<path d="M4 {front}H60V60H4z" fill="url(#front)"/>'
        f'<path d="M4 {front + 0.6}H60" stroke="#d6e8ff" stroke-width="1.2" opacity=".8"/>'
        "</g>"
        + glyph(name, 32, front + (60 - front) * 0.45, 0.95, "#ffffff")
        + f'<circle cx="51.5" cy="51.5" r="5.5" fill="{MOON}"/>'
    )
    return svg(body, FOLDER_DEFS)


# Tela's file names: the icon theme also takes every Tela alias of them.
PLACES = {
    "default-folder": None,
    "default-folder-open": "open",
    "default-folder-documents": "documents",
    "default-folder-download": "download",
    "default-folder-music": "music",
    "default-folder-pictures": "pictures",
    "default-folder-video": "videos",
    "default-folder-templates": "templates",
    "default-folder-publicshare": "publicshare",
    "default-folder-recent": "recent",
    "default-user-desktop": "desktop",
    "default-user-home": "home",
    "default-network": "network",
    "user-trash": "trash",
    "user-trash-full": "trash-full",
}

# --- File types --------------------------------------------------------------

# Symbol -> (color, Tela names). The first name gets the file, the others are
# links to it. Tela's own aliases of all of them follow (compose.py).
MIMETYPES = {
    "text": ("#4f8dff", ["text-x-generic", "text-markdown", "text-x-readme", "text-richtext"]),
    "document": ("#4f8dff", ["x-office-document", "libreoffice-oasis-text", "application-vnd.ms-word",
                             "application-msword-template",
                             "application-vnd.oasis.opendocument.text-template"]),
    "spreadsheet": ("#3fbf7f", ["x-office-spreadsheet", "libreoffice-oasis-spreadsheet",
                                "application-vnd.ms-excel",
                                "application-vnd.oasis.opendocument.spreadsheet-template"]),
    "presentation": ("#ff8a4c", ["x-office-presentation", "libreoffice-oasis-presentation",
                                 "application-vnd.ms-powerpoint",
                                 "application-vnd.oasis.opendocument.presentation-template"]),
    "pdf": ("#ff5d6c", ["application-pdf"]),
    "image": ("#2ec4c4", ["image-x-generic"]),
    "audio": ("#ff6fb0", ["audio-x-generic"]),
    "video": ("#a873ff", ["video-x-generic"]),
    "archive": ("#f0a83a", ["package-x-generic", "application-x-archive", "application-x-zip",
                            "application-x-tar", "application-x-compressed-tar",
                            "application-x-bzip-compressed-tar", "application-x-lzma-compressed-tar",
                            "application-x-gzip", "application-x-bzip", "application-x-rar"]),
    "script": ("#8ea6d8", ["text-x-script", "application-x-shellscript", "application-x-executable"]),
    "code": ("#5fc8ff", ["text-html", "text-xml", "application-json", "application-x-yaml", "text-css"]),
    "font": ("#8ea6d8", ["font-x-generic"]),
    "disc": ("#4f8dff", ["application-x-cd-image", "application-x-iso9660-image"]),
    "package": ("#4f8dff", ["application-x-rpm", "application-vnd.flatpak.ref", "application-vnd.flatpak",
                            "application-vnd.appimage"]),
    "unknown": ("#8a94ad", ["unknown", "application-octet-stream"]),
}

PAGE = "M14 5H42L54 17V55A4 4 0 0 1 50 59H14A4 4 0 0 1 10 55V9A4 4 0 0 1 14 5z"
PAGE_DEFS = ('<linearGradient id="page" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="#f7faff"/><stop offset="1" stop-color="#e3ebfa"/></linearGradient>')


def page(name, color):
    """A light page with a folded corner in the color of the file type."""
    body = (f'<path d="{PAGE}" fill="url(#page)" stroke="#b9c6e2" stroke-width="1"/>'
            f'<path d="M42 5V13A4 4 0 0 0 46 17H54z" fill="{color}"/>'
            + glyph(name, 32, 34, 1.05, color))
    return svg(body, PAGE_DEFS)


# --- Applications ------------------------------------------------------------

APP_DEFS = (
    '<linearGradient id="night" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#1a2d6b"/><stop offset="1" stop-color="#0b1736"/></linearGradient>'
    f'<linearGradient id="orbit" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="{ORBIT[0]}"/>'
    f'<stop offset="1" stop-color="{ORBIT[1]}"/></linearGradient>'
    '<linearGradient id="planet" x1=".2" y1="1" x2=".8" y2="0"><stop offset="0" stop-color="#cfeeff"/>'
    '<stop offset=".45" stop-color="#4f98f5"/><stop offset="1" stop-color="#14399e"/></linearGradient>'
)


def app(center):
    """The logo mark on a night-blue disk, with `center` inside the orbit."""
    return svg(
        '<circle cx="32" cy="32" r="28" fill="url(#night)"/>'
        '<circle cx="32" cy="32" r="27.4" fill="none" stroke="#4f8dff" stroke-opacity=".35" stroke-width="1.2"/>'
        '<g transform="translate(31 32) scale(.5)">'
        '<path d="M30.3 -25.4A40 40 0 1 0 30.3 25.4" fill="none" stroke="url(#orbit)" '
        'stroke-width="13" stroke-linecap="round"/>'
        f'<circle cx="38" cy="0" r="6.5" fill="{MOON}"/></g>' + center,
        APP_DEFS,
    )


def main():
    shutil.rmtree(LAYER, ignore_errors=True)
    places = LAYER / "places"
    mimetypes = LAYER / "mimetypes"
    places.mkdir(parents=True)
    mimetypes.mkdir()

    for name, symbol in PLACES.items():
        is_open = symbol == "open"
        (places / f"{name}.svg").write_text(folder(None if is_open else symbol, open_=is_open))

    for symbol, (color, names) in MIMETYPES.items():
        (mimetypes / f"{names[0]}.svg").write_text(page(symbol, color))
        for alias in names[1:]:
            os.symlink(f"{names[0]}.svg", mimetypes / f"{alias}.svg")

    (APPS / "cosmic-blue-welcome.svg").write_text(
        app('<circle cx="30" cy="32" r="6.5" fill="url(#planet)"/>'))
    (APPS / "cosmic-blue-installer.svg").write_text(app(glyph("download", 30, 32, 0.85, "#ffffff")))


if __name__ == "__main__":
    main()
