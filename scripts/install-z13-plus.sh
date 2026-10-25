#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
install -d /usr/share/z13-build
for repository in terrellzen/z13ctl-plus aic0d3r/z13gui-plus; do
    project=${repository##*/}
    manifest="$tmpdir/$project.json"
    curl -fsSL --retry 3 "https://api.github.com/repos/$repository/releases/latest" -o "$manifest"
    # Require exactly one native RPM, never a source RPM or another architecture.
    url=$(jq -er --arg project "$project" \
        '[.assets[] | select(.name | test("^" + $project + "_[0-9].*_linux_(amd64|x86_64)\\.rpm$")) | .browser_download_url] | if length == 1 then .[0] else error("Expected one x86_64 RPM") end' "$manifest")
    name=${url##*/}
    checksum_url=$(jq -er '[.assets[] | select(.name == "checksums.txt") | .browser_download_url] | if length == 1 then .[0] else error("Missing release checksums") end' "$manifest")
    curl -fsSL --retry 3 "$url" -o "$tmpdir/$name"
    curl -fsSL --retry 3 "$checksum_url" -o "$tmpdir/$project.checksums"
    checksum=$(awk -v name="$name" '$2 == name || $2 == "*" name {print $1}' "$tmpdir/$project.checksums")
    [[ $checksum =~ ^[0-9a-fA-F]{64}$ ]] || { echo "ERROR: Missing unique checksum for $name" >&2; exit 1; }
    (cd "$tmpdir" && printf '%s  %s\n' "$checksum" "$name" | sha256sum --check -)
    cp "$manifest" "/usr/share/z13-build/$project-release.json"
    mv "$tmpdir/$name" "$tmpdir/$project.rpm"
done
rpm-ostree install "$tmpdir/z13ctl-plus.rpm" "$tmpdir/z13gui-plus.rpm"
rpm-ostree cleanup -m

# Run the installed fork's setup generator, without contacting host udev/systemd
# or writing runtime /etc overrides. Use the existing administrator group so no
# account membership changes are needed. These files are part of the image.
z13ctl-plus --dry-run setup --group=wheel > "$tmpdir/setup.txt"
python3 /usr/libexec/z13-build/generate-z13-permissions.py "$tmpdir/setup.txt" "$tmpdir"
install -Dm0644 "$tmpdir/99-z13ctl-plus.rules" /usr/lib/udev/rules.d/99-z13ctl-plus.rules
install -Dm0644 "$tmpdir/z13ctl-plus-perms.service" /usr/lib/systemd/system/z13ctl-plus-perms.service
