#!/usr/bin/bash
# Text checks of the terminal, run in the test virtual machine as the test
# user's login shell (vm-lib.sh, terminal_checks):
#   runuser -u demo -- bash -l -s -- <project dir> < tests/vm-terminal-checks.sh
# Makes a small git project for the terminal screenshot, then checks the
# cosmic-blue prompt (Starship) and fastfetch. Prints one "FAIL <reason>" line
# per problem; always exits 0.
export LC_ALL=C.UTF-8
project="$1"

cd ~ && mkdir -p "${project}" && cd "${project}" \
    || { echo "FAIL could not make ~/${project}"; exit 0; }
if [[ ! -d .git ]]; then
    { git init -q \
        && printf '# hello\n' > README.md \
        && git add README.md \
        && git -c user.name=demo -c user.email=demo@localhost commit -q -m 'First commit' \
        && printf 'A change\n' >> README.md
    } || echo "FAIL could not make a git project for the prompt"
fi

# Prompt: the cosmic-blue config (/etc/profile.d/90-starship.sh), valid
# (Starship reports config errors on stderr), with the cosmic-blue Prompt font
# symbols: logo, arrow, git branch and failed status
if [[ "${STARSHIP_CONFIG:-}" != /usr/share/cosmic-blue/starship.toml ]]; then
    echo "FAIL the login shell does not use the cosmic-blue prompt (STARSHIP_CONFIG='${STARSHIP_CONFIG:-}')"
fi
errors="$(mktemp)"
prompt="$(starship prompt --status 1 2>"${errors}")" \
    || echo "FAIL starship prompt exited with an error"
if [[ -s "${errors}" ]]; then
    echo "FAIL starship printed errors: $(head -c 400 "${errors}" | tr '\n' ' ')"
fi
rm -f "${errors}"
for symbol in $'\U10cb00:logo' $'\U10cb01:arrow' $'\U10cb02:git branch' $'\U10cb03:failed status'; do
    [[ "${prompt}" == *"${symbol%%:*}"* ]] || echo "FAIL the prompt has no ${symbol#*:} symbol"
done
[[ "${prompt}" == *hello* ]] || echo "FAIL the prompt does not show the current folder"

# fastfetch: the ff alias and a cosmic-blue report without errors
alias ff >/dev/null 2>&1 || echo "FAIL the ff alias is missing"
report="$(ublue-fastfetch 2>&1)" || echo "FAIL ublue-fastfetch exited with an error"
[[ "${report}" == *cosmic-blue* ]] || echo "FAIL fastfetch does not show cosmic-blue"
if grep -qi error <<< "${report}"; then
    echo "FAIL fastfetch printed an error: $(grep -i error <<< "${report}" | head -n 3 | tr '\n' ' ')"
fi
exit 0
