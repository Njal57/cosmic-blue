#!/usr/bin/bash
# Replaces Fedora's cosmic-greeter binary (login and lock screens) with the one
# rebuilt from the same source package with the cosmic-blue wallpaper as its
# built-in background (see build_files/greeter/build.sh).
set -euox pipefail

installed="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' cosmic-greeter)"
built="$(cat /ctx/greeter/version)"
if [ "${installed}" != "${built}" ]; then
    echo "cosmic-greeter ${installed} installed, but ${built} was rebuilt" >&2
    exit 1
fi

install -m 0755 /ctx/greeter/cosmic-greeter /usr/bin/cosmic-greeter
