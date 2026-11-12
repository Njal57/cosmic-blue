#!/usr/bin/bash
# Default icon theme: "cosmic-blue", COSMIC's symbolic icons with Tela circle
# (dark variant, recolored with the cosmic-blue accent) for applications,
# folders and file types. Tela circle is built in the Containerfile's "icons"
# stage (see build_files/icon_theme/tela.sh).
set -euox pipefail

cp -a /ctx/icons/. /usr/share/icons/

python3 /ctx/build_files/icon_theme/compose.py
if command -v gtk-update-icon-cache >/dev/null; then
    for theme in Tela-circle-4f8dff Tela-circle-4f8dff-dark cosmic-blue; do
        gtk-update-icon-cache --force "/usr/share/icons/${theme}"
    done
fi
