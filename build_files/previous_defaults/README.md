# Previous defaults

Values that accounts may hold as a copy of an old default rather than as a
choice of their own. `cosmic-blue-migrate-defaults` resets such a copy when
the image default changes, so the account follows the new default.

Each directory is a tree of settings, with the paths of `/usr/share/cosmic`
(and `gsettings/<schema>/<key>` for GSettings values, as `gsettings get`
prints them). The build hashes them into
`/usr/share/cosmic-blue/previous-defaults.list`, together with Fedora's
packaged COSMIC defaults and the earlier default themes
(`build_files/theme`, variants `stock` and `frosted`).

- `upstream`: built-in defaults of COSMIC and GNOME that no package ships as a
  file (COSMIC's own icon theme, GTK's Adwaita icons and cursors).

Defaults that change from now on need no entry here: each account remembers
the defaults it last had (`~/.local/state/cosmic-blue/defaults.list`).
