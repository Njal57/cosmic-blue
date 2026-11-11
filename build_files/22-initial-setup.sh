#!/usr/bin/bash
# Replaces Fedora's cosmic-initial-setup binary with the one rebuilt from the
# same source package with the cosmic-blue patches (build_files/initial_setup):
# its appearance page keeps the cosmic-blue theme and it does not turn on the
# screen reader at start.
set -euox pipefail

installed="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' cosmic-initial-setup)"
built="$(cat /ctx/initial_setup/version)"
if [ "${installed}" != "${built}" ]; then
    echo "cosmic-initial-setup ${installed} installed, but ${built} was patched" >&2
    exit 1
fi

install -m 0755 /ctx/initial_setup/cosmic-initial-setup /usr/bin/cosmic-initial-setup
