#!/usr/bin/env bash
set -euo pipefail

# On Fedora the qt6-qttools executable is qdbus-qt6, not qdbus6.
# The tablet kit requires the latter name for touchscreen detection.
if [[ ! -x /usr/bin/qdbus-qt6 ]]; then
    echo 'ERROR: qt6-qttools did not provide /usr/bin/qdbus-qt6' >&2
    exit 1
fi
if [[ ! -e /usr/bin/qdbus6 ]]; then
    ln -s /usr/bin/qdbus-qt6 /usr/bin/qdbus6
fi

# The RPM is expected to ship the official hardware-permission units/rules.
rpm -ql z13ctl-plus | grep -E '/udev/rules.d/.*\.rules$'
systemctl enable z13ctl-plus-perms.service
systemctl --global enable z13ctl-plus.socket
systemctl --global enable z13ctl-plus.service
systemctl --global enable z13gui-plus.service

chmod +x /usr/bin/bt-auto-reconnect.sh /usr/lib/systemd/system-sleep/usb-wakeup-fix
sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf
systemctl enable bluetooth-poweron.service bt-auto-reconnect.service
