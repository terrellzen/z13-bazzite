#!/usr/bin/env bash
set -euo pipefail

# Download the latest stable x86_64 RPM for each Plus project.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

for project in z13ctl-plus z13gui-plus; do
    api="https://api.github.com/repos/aic0d3r/${project}/releases/latest"
    url="$(curl -fsSL --retry 3 "$api" | jq -r '[.assets[].browser_download_url | select(endswith(".rpm")) | select(test("x86_64|amd64"))][0] // empty')"
    if [[ -z "$url" ]]; then
        echo "ERROR: No x86_64 RPM in latest release of $project" >&2
        exit 1
    fi
    echo "Downloading $project from $url"
    curl -fL --retry 3 "$url" -o "$tmpdir/$project.rpm"
done

rpm-ostree install "$tmpdir/z13ctl-plus.rpm" "$tmpdir/z13gui-plus.rpm"
rpm-ostree cleanup -m
