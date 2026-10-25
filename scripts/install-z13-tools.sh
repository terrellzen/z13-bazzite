#!/usr/bin/env bash
set -euo pipefail

# Stock Bazzite may already include ASUS tools. Keep one hardware daemon.
remove=()
for package in asusctl asusctl-rog-gui rog-control-center; do
    if rpm -q "$package" >/dev/null 2>&1; then
        remove+=("$package")
    fi
done
if (( ${#remove[@]} )); then
    rpm-ostree override remove "${remove[@]}"
fi

# Use the original upstream projects, including their units and device rules.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
for project in z13ctl z13gui; do
    api="https://api.github.com/repos/dahui/${project}/releases/latest"
    url=$(curl -fsSL --retry 3 "$api" | jq -r \
        '[.assets[].browser_download_url | select(endswith(".rpm")) | select(test("x86_64|amd64"))][0] // empty')
    [[ -n $url ]] || { echo "ERROR: No x86_64 RPM in latest release of $project" >&2; exit 1; }
    echo "Downloading $project from $url"
    curl -fL --retry 3 "$url" -o "$tmpdir/$project.rpm"
done
rpm-ostree install "$tmpdir/z13ctl.rpm" "$tmpdir/z13gui.rpm"
rpm-ostree cleanup -m
