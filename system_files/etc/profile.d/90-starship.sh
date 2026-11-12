# shellcheck shell=sh
command -v starship >/dev/null 2>&1 || return 0

if [ "$(basename "$(readlink /proc/$$/exe)")" = "bash" ]; then
  # cosmic-blue prompt (powerline segments, Nerd Font symbols), unless the
  # user has their own ~/.config/starship.toml or STARSHIP_CONFIG, or is on
  # the Linux console, which cannot show the symbols. Checked again in each
  # shell, so a config created later is picked up by new terminals.
  COSMIC_BLUE_STARSHIP=/usr/share/cosmic-blue/starship.toml
  if [ "${STARSHIP_CONFIG:-}" = "${COSMIC_BLUE_STARSHIP}" ]; then
    unset STARSHIP_CONFIG
  fi
  if [ -z "${STARSHIP_CONFIG:-}" ] && [ ! -e "${HOME}/.config/starship.toml" ] &&
    [ "${TERM:-}" != linux ]; then
    export STARSHIP_CONFIG="${COSMIC_BLUE_STARSHIP}"
  fi
  unset COSMIC_BLUE_STARSHIP
  eval "$(starship init bash)"
fi
