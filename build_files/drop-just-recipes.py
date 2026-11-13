#!/usr/bin/env python3
"""Remove recipes from a justfile, with their doc comments and attributes.

Usage: drop-just-recipes.py FILE RECIPE...

Used on projectbluefin/common's ujust files for Bluefin-only recipes. A recipe
starts at an unindented "name ...:" line; the comment and [attribute] lines
right above it belong to it, and its body is every indented or blank line that
follows. Aliases pointing to a removed recipe go too. Fails if a recipe is not
found, so that an upstream rename is noticed at build time.
"""
import re
import sys

HEADER = re.compile(r"^([A-Za-z_][\w-]*)\b(?!\s*:=).*:(?!=)")
ALIAS = re.compile(r"^alias\s+[\w-]+\s*:=\s*([\w-]+)\s*$")


def main() -> int:
    path, drop = sys.argv[1], set(sys.argv[2:])
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines(keepends=True)

    out, pending, found = [], [], set()
    skipping = False
    for line in lines:
        if skipping:
            if not line.strip() or line[0] in " \t":
                continue
            skipping = False
        if line.startswith(("#", "[")):
            pending.append(line)
            continue
        alias = ALIAS.match(line)
        if alias and alias.group(1) in drop:
            pending = []
            continue
        header = HEADER.match(line)
        if header and not line.startswith(("alias ", "set ", "import", "mod ", "export ")):
            name = header.group(1)
            if name in drop:
                found.add(name)
                pending = []
                skipping = True
                continue
        out.extend(pending)
        out.append(line)
        pending = []
    out.extend(pending)

    missing = drop - found
    if missing:
        print(f"{path}: recipes not found: {' '.join(sorted(missing))}", file=sys.stderr)
        return 1
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
