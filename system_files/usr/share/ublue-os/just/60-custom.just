# vim: set ft=make :
# cosmic-blue desktop commands, listed by `ujust` under "Desktop".
#
# COSMIC reads each setting from ~/.config/cosmic first and falls back to the
# image defaults in /usr/share/cosmic. Resetting a setting therefore means
# removing the user's copy, so later image updates of the defaults apply again.

# Switch between the dark and light theme (or force one: dark, light)
[group('Desktop')]
toggle-dark-mode mode="toggle":
    #!/usr/bin/bash
    set -euo pipefail
    key="com.system76.CosmicTheme.Mode/v1"
    user_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/cosmic/${key}"
    read_setting() { # name default
        cat "${user_dir}/$1" 2>/dev/null || cat "/usr/share/cosmic/${key}/$1" 2>/dev/null || echo "$2"
    }
    write_setting() { # name value
        install -d "${user_dir}"
        printf '%s' "$2" >"${user_dir}/$1.tmp"
        mv -f "${user_dir}/$1.tmp" "${user_dir}/$1"
    }
    case "{{ mode }}" in
        dark) is_dark=true ;;
        light) is_dark=false ;;
        toggle)
            if [[ "$(read_setting is_dark true)" == true ]]; then is_dark=false; else is_dark=true; fi
            ;;
        *)
            echo "Usage: ujust toggle-dark-mode [toggle|dark|light]" >&2
            exit 1
            ;;
    esac
    # Automatic switching at sunrise and sunset would undo the choice
    if [[ "$(read_setting auto_switch false)" == true ]]; then
        write_setting auto_switch false
        echo "Automatic switching between light and dark turned off."
    fi
    write_setting is_dark "${is_dark}"
    if [[ "${is_dark}" == true ]]; then echo "Dark theme on."; else echo "Light theme on."; fi

# Restore the cosmic-blue look: colors, dark mode, icons and wallpaper
[group('Desktop')]
reset-cosmic-theme:
    #!/usr/bin/bash
    set -euo pipefail
    config="${XDG_CONFIG_HOME:-${HOME}/.config}/cosmic"
    # Accent, frosted glass and colors; dark/light mode; icon theme and fonts;
    # wallpaper
    settings=(
        com.system76.CosmicTheme.Dark
        com.system76.CosmicTheme.Dark.Builder
        com.system76.CosmicTheme.Light
        com.system76.CosmicTheme.Light.Builder
        com.system76.CosmicTheme.Mode
        com.system76.CosmicTk
        com.system76.CosmicBackground
    )
    echo "This restores the cosmic-blue colors, dark theme, icons, fonts and wallpaper."
    echo "Other COSMIC settings (panel, dock, keyboard, shortcuts...) are kept."
    if ! gum confirm "Reset the appearance?"; then
        exit 0
    fi
    for setting in "${settings[@]}"; do
        rm -rf "${config:?}/${setting}"
    done
    echo "Done. Log out and back in to see every change."

# Reset all COSMIC settings to the cosmic-blue defaults (a backup is kept)
[group('Desktop')]
reset-cosmic-config:
    #!/usr/bin/bash
    set -euo pipefail
    config="${XDG_CONFIG_HOME:-${HOME}/.config}/cosmic"
    if [[ ! -d "${config}" ]]; then
        echo "No COSMIC settings to reset."
        exit 0
    fi
    backup="${config}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "This resets every COSMIC setting: appearance, panel, dock, shortcuts, applets..."
    echo "Your keyboard layout and clock format are kept."
    echo "Current settings will be moved to ${backup}"
    if ! gum confirm "Reset all COSMIC settings?"; then
        exit 0
    fi
    mv "${config}" "${backup}"
    # Keyboard layout and clock format, set from the installer choices
    keep=(
        com.system76.CosmicComp/v1/xkb_config
        com.system76.CosmicAppletTime/v1/military_time
        com.system76.CosmicAppletTime/v1/first_day_of_week
    )
    for setting in "${keep[@]}"; do
        if [[ -f "${backup}/${setting}" ]]; then
            install -D -m 0644 "${backup}/${setting}" "${config}/${setting}"
        fi
    done
    echo "Done. Log out and back in to finish the reset."
    echo "To undo it: rm -rf '${config}' && mv '${backup}' '${config}', then log out."
