#!/usr/bin/env bash
set -euo pipefail

src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT
git clone --depth 1 https://github.com/aic0d3r/z13-tablet-kit.git "$src/kit"

install -d /usr/lib/z13-tablet-kit /usr/lib/systemd/user /usr/lib/udev/rules.d
for program in dock z13-tablet-switch z13-touch-scroll; do
    install -m 0755 "$src/kit/bin/$program" "/usr/lib/z13-tablet-kit/$program"
done
cp "$src/kit"/systemd/*.service /usr/lib/systemd/user/
sed -i 's#%h/.local/bin/#/usr/lib/z13-tablet-kit/#g' \
    /usr/lib/systemd/user/z13-tablet-switch.service \
    /usr/lib/systemd/user/z13-touch-scroll.service
cp "$src/kit"/udev/*.rules /usr/lib/udev/rules.d/

# Keep the upstream touchpad inhibition rule; GUI opt-in needs users-group access.
systemctl --global enable z13-tablet-switch.service z13-touch-scroll.service
