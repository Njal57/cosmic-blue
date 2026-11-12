#!/usr/bin/bash
# VS Code: default settings and the container/remote extensions, once per user.
# Recorded only on success, so an offline first login retries on the next one.

source /usr/lib/ublue/setup-services/libsetup.sh

version-script-check vscode user 1 || exit 0

set -euxo pipefail

if test ! -e "$HOME"/.config/Code/User/settings.json; then
    mkdir -p "$HOME"/.config/Code/User
    cp -f /etc/skel/.config/Code/User/settings.json "$HOME"/.config/Code/User/settings.json
fi

code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-azuretools.vscode-containers

version-script-commit vscode user 1
