#!/usr/bin/bash
# List of the image defaults (COSMIC settings and GSettings keys), with a hash
# of each value. cosmic-blue-migrate-defaults compares it at boot with the list
# each account last saw, to find the defaults an update changed.
# Runs after every step that changes /usr/share/cosmic.
set -euox pipefail

/usr/libexec/cosmic-blue-migrate-defaults --manifest >/usr/share/cosmic-blue/defaults.list
wc -l /usr/share/cosmic-blue/defaults.list
grep ' com.system76.CosmicTk/v1/icon_theme$' /usr/share/cosmic-blue/defaults.list
