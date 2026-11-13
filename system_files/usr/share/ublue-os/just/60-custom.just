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

# Save your COSMIC settings to one text file, to share them or propose them as defaults
[group('Desktop')]
export-cosmic-config:
    #!/usr/bin/bash
    set -euo pipefail
    config="${XDG_CONFIG_HOME:-${HOME}/.config}/cosmic"
    if [[ ! -d "${config}" ]]; then
        echo "No COSMIC settings to export: every setting is still the default."
        exit 0
    fi
    out="${HOME}/cosmic-config-$(date +%Y%m%d-%H%M%S).txt"
    # Left out on purpose:
    # - the computed themes (CosmicTheme.Dark/Light): COSMIC rebuilds them
    #   from the .Builder settings, which are exported
    # - the keyboard layout and clock format, set from the installer choices
    #   on every install
    # - any file naming the home folder or the user name (recent files,
    #   bookmarks, personal wallpapers...), binary files and big files
    skip_dirs=(
        com.system76.CosmicTheme.Dark/
        com.system76.CosmicTheme.Light/
    )
    skip_files=(
        com.system76.CosmicComp/v1/xkb_config
    )
    user_name="$(id -un)"
    exported=0
    skipped=()
    {
        echo "# cosmic-blue: COSMIC settings export"
        echo "# Date: $(date -u +%Y-%m-%dT%H:%MZ)"
        echo "# Image: $(jq -r '."image-ref" + " " + ."image-tag"' /usr/share/ublue-os/image-info.json 2>/dev/null || echo unknown)"
        echo "# COSMIC: $(rpm -q --qf '%{VERSION}' cosmic-settings 2>/dev/null || echo unknown)"
        echo "# Each file starts with a '===== <path> =====' line; paths are relative to ~/.config/cosmic."
    } >"${out}"
    while IFS= read -r -d '' file; do
        rel="${file#"${config}/"}"
        reason=""
        for dir in "${skip_dirs[@]}"; do
            [[ "${rel}" == "${dir}"* ]] && reason="rebuilt by COSMIC"
        done
        for name in "${skip_files[@]}"; do
            [[ "${rel}" == "${name}" ]] && reason="set by the installer"
        done
        if [[ -z "${reason}" ]]; then
            if [[ "$(stat -c %s "${file}")" -gt 65536 ]]; then
                reason="bigger than 64 KB"
            elif [[ -s "${file}" ]] && ! grep -qI . "${file}"; then
                reason="binary"
            elif grep -qF -e "${HOME}" -e "/home/" -e "/var/home/" "${file}" \
                || grep -qw -- "${user_name}" "${file}"; then
                reason="personal"
            fi
        fi
        if [[ -n "${reason}" ]]; then
            skipped+=("${rel} (${reason})")
            continue
        fi
        printf '\n===== %s =====\n' "${rel}" >>"${out}"
        cat "${file}" >>"${out}"
        printf '\n' >>"${out}"
        exported=$((exported + 1))
    done < <(find "${config}" -type f ! -name '*.tmp' -print0 | sort -z)
    {
        echo
        echo "# Left out (${#skipped[@]}):"
        for item in "${skipped[@]}"; do echo "#   ${item}"; done
    } >>"${out}"
    echo "Saved ${exported} settings to ${out}"
    if [[ "${#skipped[@]}" -gt 0 ]]; then
        echo "Left out ${#skipped[@]} files (listed at the end of the export):"
        printf '  %s\n' "${skipped[@]}"
    fi
    echo "It is plain text: read it before sharing it."
