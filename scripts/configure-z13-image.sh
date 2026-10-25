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

# RPM post-install scripts can create /etc enablement links during the build.
# Keep enablement in /usr so it follows the image on rebase.
for link in /etc/systemd/system/multi-user.target.wants/z13ctl-plus-perms.service \
    /etc/systemd/user/sockets.target.wants/z13ctl-plus.socket \
    /etc/systemd/user/graphical-session.target.wants/z13ctl-plus.service \
    /etc/systemd/user/graphical-session.target.wants/z13gui-plus.service; do
    if [[ -L $link ]]; then unlink "$link"; fi
done
install -d /usr/lib/systemd/system/multi-user.target.wants \
    /usr/lib/systemd/user/sockets.target.wants \
    /usr/lib/systemd/user/graphical-session.target.wants
ln -sfn ../z13ctl-plus-perms.service /usr/lib/systemd/system/multi-user.target.wants/z13ctl-plus-perms.service
ln -sfn ../z13ctl-plus.socket /usr/lib/systemd/user/sockets.target.wants/z13ctl-plus.socket
for unit in z13ctl-plus.service z13gui-plus.service; do
    ln -sfn "../$unit" "/usr/lib/systemd/user/graphical-session.target.wants/$unit"
done
chmod +x /usr/bin/bt-auto-reconnect.sh /usr/lib/systemd/system-sleep/usb-wakeup-fix
sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf
for unit in bluetooth-poweron.service bt-auto-reconnect.service; do
    ln -sfn "../$unit" "/usr/lib/systemd/system/multi-user.target.wants/$unit"
done
