#!/usr/bin/env bash
set -euo pipefail

# Keep ASUS control daemons out of the test image, including base-image packages.
remove=()
for package in asusctl asusctl-rog-gui rog-control-center; do
    if rpm -q "$package" >/dev/null 2>&1; then
        remove+=("$package")
    fi
done
if (( ${#remove[@]} )); then
    rpm-ostree override remove "${remove[@]}"
fi

# Only the Bluetooth helpers are enabled by this image. Layered Z13 packages
# own their binaries, hardware permissions, and service enablement.
install -d /usr/lib/systemd/system/multi-user.target.wants
chmod +x /usr/bin/bt-auto-reconnect.sh /usr/lib/systemd/system-sleep/usb-wakeup-fix
sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf
for unit in bluetooth-poweron.service bt-auto-reconnect.service; do
    ln -sfn "../$unit" "/usr/lib/systemd/system/multi-user.target.wants/$unit"
done
