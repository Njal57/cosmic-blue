#!/usr/bin/env bash
# Downloads the desktop screenshots of the latest published image for the
# screenshots page: the boot test of build.yml (tests/vm-boot-test.sh) logs a
# test user in and takes them in a virtual machine. Artifacts last 7 days and
# main is built every day, so a recent one is always there.
#
# Usage: website/fetch-screenshots.sh <output directory>
# Writes the screenshots (PNG or PPM) and info.env (date, commit, run URL).
# Needs gh with GH_TOKEN (actions: read) and GITHUB_REPOSITORY.
# Never fails: without screenshots, the site is built without them.
set -uo pipefail

out="$1"
repo="${GITHUB_REPOSITORY:-cosmic-blue-os/cosmic-blue}"
artifact="boot-test-cosmic-blue"  # boot-test-${IMAGE_NAME} in build.yml
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${out}"

# Published builds of main, newest first (pull request runs publish nothing)
runs="$(gh run list -R "${repo}" --workflow build.yml --branch main --status success \
    --limit 30 --json databaseId,event,headSha,createdAt,url \
    --jq '.[] | select(.event != "pull_request") | [.databaseId, .headSha, .createdAt, .url] | @tsv')" || {
    echo "::warning::Screenshots: could not list the image builds"; exit 0; }

while IFS=$'\t' read -r id sha created url; do
    [[ -n "${id}" ]] || continue
    gh api "repos/${repo}/actions/runs/${id}/artifacts" \
        --jq ".artifacts[] | select(.name == \"${artifact}\" and (.expired | not)) | .id" \
        | grep -q . || continue
    rm -rf "${tmp:?}"/*
    gh run download "${id}" -R "${repo}" -n "${artifact}" -D "${tmp}" >/dev/null || continue
    # Only a run where the test user got to the desktop
    compgen -G "${tmp}/screenshots/*-desktop.*" >/dev/null || continue
    cp "${tmp}"/screenshots/* "${out}/"
    printf 'SHOTS_DATE=%s\nSHOTS_COMMIT=%s\nSHOTS_RUN=%s\n' \
        "${created%%T*}" "${sha:0:7}" "${url}" > "${out}/info.env"
    echo "Screenshots from run ${url} (${sha:0:7}, ${created}):"
    ls "${out}"
    exit 0
done <<< "${runs}"

echo "::warning::Screenshots: no recent image build with desktop screenshots"
exit 0
