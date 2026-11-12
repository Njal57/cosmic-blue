#!/usr/bin/env python3
"""Build the cosmic-blue icon theme in /usr/share/icons/cosmic-blue.

The theme takes everything from the dark variant of Tela circle, recolored
with the cosmic-blue accent (installed by build_files/icon_theme/tela.sh):
applications, folders, file types and symbolic (monochrome) icons. COSMIC's
own themes (Cosmic, then Pop) only provide the symbolic icons that Tela
lacks, mostly COSMIC-specific ones (settings pages, applets).

Only symlinks and an index.theme are created: the icons themselves stay in
their themes.
"""

import configparser
import os
import sys

ICONS = os.environ.get("ICONS_DIR", "/usr/share/icons")
THEME = "cosmic-blue"

TELA = "Tela-circle-4f8dff-dark"
# Themes whose symbolic icons we take, in order of preference.
SYMBOLIC_SOURCES = [TELA, "Cosmic", "Pop"]
# Tela's "panel" icons are drawn for light-on-dark tray areas only.
SKIP_DIRS = ("/panel",)
# Full-color icons and fallback for any other name.
INHERITS = [TELA, "Cosmic", "Pop", "Adwaita", "hicolor"]

# Tela has no icons for the COSMIC applications (their IDs are
# com.system76.*). Point them to the matching Tela icon.
COSMIC_APPS = {
    "com.system76.CosmicEdit": "accessories-text-editor",
    "com.system76.CosmicFiles": "system-file-manager",
    "com.system76.CosmicPlayer": "multimedia-video-player",
    "com.system76.CosmicScreenshot": "applets-screenshooter",
    "com.system76.CosmicSettings": "preferences-system",
    "com.system76.CosmicStore": "system-software-install",
    "com.system76.CosmicTerm": "utilities-terminal",
}


def read_index(theme):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str  # keys are case-sensitive
    parser.read(os.path.join(ICONS, theme, "index.theme"), encoding="utf-8")
    return parser


def section(parser, name):
    return {key: value for key, value in parser.items(name)}


def link(target, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    os.symlink(os.path.relpath(target, os.path.dirname(path)), path)


def main():
    root = os.path.join(ICONS, THEME)
    if os.path.exists(root):
        sys.exit(f"{root} already exists")

    directories = {}  # directory in our theme -> its index.theme section
    taken = set()  # symbolic icon names already provided by our theme
    links = 0

    for source in SYMBOLIC_SOURCES:
        index = read_index(source)
        # A name comes from a single source theme, so that icons of another
        # size from the next source can't win the size match.
        before = set(taken)
        for subdir in index.get("Icon Theme", "Directories").split(","):
            subdir = subdir.strip()
            path = os.path.join(ICONS, source, subdir)
            if (not subdir or subdir.endswith(SKIP_DIRS) or not index.has_section(subdir)
                    or not os.path.isdir(path)):
                continue
            ours = f"{source.split('-')[0].lower()}/{subdir}"
            for name in sorted(os.listdir(path)):
                stem, _ = os.path.splitext(name)
                if not stem.endswith("-symbolic") or stem in before:
                    continue
                if not os.path.exists(os.path.join(path, name)):
                    continue  # dangling upstream link
                link(os.path.join(path, name), os.path.join(root, ours, name))
                taken.add(stem)
                links += 1
                directories[ours] = section(index, subdir)

    tela = read_index(TELA)
    count = 0
    for subdir in tela.get("Icon Theme", "Directories").split(","):
        subdir = subdir.strip()
        if not subdir.endswith("/apps") or "symbolic" in subdir:
            continue
        for app_id, icon in COSMIC_APPS.items():
            target = os.path.join(ICONS, TELA, subdir, f"{icon}.svg")
            if not os.path.exists(target):
                continue
            ours = f"tela/{subdir}"
            link(target, os.path.join(root, ours, f"{app_id}.svg"))
            directories[ours] = section(tela, subdir)
            count += 1

    out = configparser.ConfigParser(interpolation=None)
    out.optionxform = str
    out["Icon Theme"] = {
        "Name": THEME,
        "Comment": "Tela circle (cosmic-blue accent) with COSMIC symbolic icons as fallback",
        "Inherits": ",".join(INHERITS),
        "Example": "folder",
        "Directories": ",".join(sorted(directories)),
    }
    for name in sorted(directories):
        out[name] = directories[name]
    with open(os.path.join(root, "index.theme"), "w", encoding="utf-8") as handle:
        out.write(handle, space_around_delimiters=False)

    print(f"{THEME}: {len(taken)} symbolic icons ({links} links), {count} COSMIC app icon links, "
          f"{len(directories)} directories")


if __name__ == "__main__":
    main()
