#!/usr/bin/env python3
"""Write the release notes of a stable image in Markdown.

Compares the package lists of the previous and the new stable image
(`rpm -qa --qf '%{NAME}\t%{EVR}\n'`, one file each) and lists the
cosmic-blue commits between the two builds.

Usage: release-notes.py --new new.tsv [--old old.tsv] --title TITLE
       [--image REF] [--commits commits.tsv] [--compare-url URL]
"""
import argparse
import re
import sys
from collections import defaultdict

# Packages that make up the COSMIC desktop (shown first)
COSMIC = re.compile(r"^(cosmic-.*|xdg-desktop-portal-cosmic|pop-launcher|pop-icon-theme)$")
# Base system packages worth a line of their own
HIGHLIGHTS = [
    "kernel", "mesa-dri-drivers", "linux-firmware", "systemd", "bootc",
    "rpm-ostree", "flatpak", "podman", "NetworkManager", "pipewire",
]
# Not packages: imported signing keys
IGNORED = {"gpg-pubkey", "gpg-pubkey-release"}
# GitHub release bodies are limited to 125000 characters
MAX_LENGTH = 120000


def read_packages(path):
    packages = defaultdict(set)
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 2 or not parts[0] or parts[0] in IGNORED:
                continue
            packages[parts[0]].add(parts[1])
    return {name: ", ".join(sorted(evrs)) for name, evrs in packages.items()}


def diff(old, new):
    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    updated = sorted(n for n in set(old) & set(new) if old[n] != new[n])
    return added, removed, updated


def table(rows):
    lines = ["| Package | Previous | New |", "| --- | --- | --- |"]
    lines += [f"| {name} | {before} | {after} |" for name, before, after in rows]
    return lines


def rows_for(names, old, new):
    return [(n, f"`{old[n]}`" if n in old else "-", f"`{new[n]}`" if n in new else "-")
            for n in names]


def version(packages, name):
    """Upstream version of a package (EVR without epoch and release)."""
    evr = packages.get(name)
    if not evr:
        return None
    return evr.split(":")[-1].rsplit("-", 1)[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--new", required=True)
    parser.add_argument("--old")
    parser.add_argument("--title", required=True)
    parser.add_argument("--image")
    parser.add_argument("--commits")
    parser.add_argument("--compare-url")
    args = parser.parse_args()

    new = read_packages(args.new)
    if not new:
        sys.exit(f"No packages in {args.new}")
    old = read_packages(args.old) if args.old else {}
    added, removed, updated = diff(old, new) if old else ([], [], [])
    changed = added + removed + updated

    out = [f"# {args.title}", ""]
    if args.image:
        out += [f"Image: `{args.image}`", ""]
    out += ["Installed systems get this version with the next automatic update "
            "(or `ujust update`), then a reboot.", ""]

    # COSMIC first
    out += ["## COSMIC", ""]
    new_cosmic, old_cosmic = version(new, "cosmic-settings"), version(old, "cosmic-settings")
    if not old:
        out += [f"COSMIC {new_cosmic or 'not found'}.", ""]
    elif new_cosmic != old_cosmic:
        out += [f"COSMIC **{old_cosmic} → {new_cosmic}**.", ""]
    else:
        out += [f"COSMIC {new_cosmic}.", ""]
    cosmic_changes = sorted(n for n in changed if COSMIC.match(n))
    if cosmic_changes:
        out += table(rows_for(cosmic_changes, old, new)) + [""]
    elif old:
        out += ["No COSMIC package changed.", ""]

    # Main base system packages
    out += ["## System", ""]
    for name in HIGHLIGHTS:
        if name not in new and name not in old:
            continue
        if old and old.get(name) != new.get(name):
            out.append(f"- {name}: `{old.get(name, '-')}` → **`{new.get(name, '-')}`**")
        else:
            out.append(f"- {name}: `{new.get(name, '-')}`")
    out.append("")

    # cosmic-blue's own changes
    if args.commits:
        with open(args.commits, encoding="utf-8") as f:
            commits = [line.rstrip("\n").split("\t", 1) for line in f if line.strip()]
        out += ["## cosmic-blue changes", ""]
        if commits:
            out += [f"- {subject} ({sha[:7]})" for sha, subject in commits]
        else:
            out.append("No change in this repository.")
        if args.compare_url:
            out += ["", f"Full diff: {args.compare_url}"]
        out.append("")

    # Every package change
    if old:
        out += ["## All package changes", "",
                f"{len(updated)} updated, {len(added)} added, {len(removed)} removed.", ""]
        sections = [("Updated", updated), ("Added", added), ("Removed", removed)]
        for label, names in sections:
            if not names:
                continue
            out += ["<details>", f"<summary>{label} ({len(names)})</summary>", ""]
            out += table(rows_for(names, old, new))
            out += ["", "</details>", ""]
    else:
        out += ["First stable release with release notes: "
                f"{len(new)} packages, no previous version to compare with.", ""]

    text = "\n".join(out)
    if len(text) > MAX_LENGTH:
        cut = text.rfind("\n", 0, MAX_LENGTH)
        text = text[:cut] + "\n\n*(list cut: too many changes for a release page)*\n"
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
