#!/usr/bin/env bash
# Earlier cosmic-blue images shipped projectbluefin/common's FlatPark remote, a
# third-party Flatpak hub, in /usr/share/flatpak/remotes.d. Flatpak copied it
# into the system installation, so it stays after the file is gone: remove it,
# unless apps were installed from it (then it is kept, so they still update).

source /usr/lib/ublue/setup-services/libsetup.sh

version-script-check remove-flatpark system 1 || exit 0

set -euo pipefail

if flatpak remotes --system --columns=name | grep -qx flatpark; then
    if flatpak list --system --columns=origin | grep -qx flatpark; then
        echo "FlatPark remote kept: apps were installed from it"
    else
        flatpak remote-delete --system flatpark
        echo "FlatPark remote removed"
    fi
fi

version-script-commit remove-flatpark system 1
