#!/usr/bin/env bash
set -euo pipefail

# A module compiled for the wrong kernel must not be published.
mapfile -t kernels < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
if (( ${#kernels[@]} != 1 )); then
    printf 'ERROR: expected one target kernel, found: %s\n' "${kernels[*]}" >&2
    exit 1
fi
kernel="${kernels[0]}"
if [[ ! -d "/usr/src/kernels/$kernel" ]]; then
    echo "ERROR: Missing matching kernel-devel: /usr/src/kernels/$kernel" >&2
    exit 1
fi

src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT
git clone --depth 1 https://github.com/amkillam/ryzen_smu.git "$src/ryzen_smu"
make -C "/usr/src/kernels/$kernel" M="$src/ryzen_smu" modules
install -Dm0644 "$src/ryzen_smu/ryzen_smu.ko" \
    "/usr/lib/modules/$kernel/updates/ryzen_smu.ko"
depmod -a "$kernel"
install -d /usr/lib/modules-load.d
printf 'ryzen_smu\n' > /usr/lib/modules-load.d/ryzen_smu.conf
