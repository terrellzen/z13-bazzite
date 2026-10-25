#!/usr/bin/env bash
set -euo pipefail

chmod 0755 /usr/bin/z13-post-setup /usr/libexec/z13-configure-permissions /usr/libexec/z13-desktop-setup
chmod 0644 /usr/share/applications/z13-first-time-setup.desktop \
    /etc/xdg/autostart/z13-desktop-setup.desktop \
    /usr/share/z13-setup/libuser.conf \
    /usr/share/polkit-1/actions/org.z13.configure-permissions.policy

# The RPM is expected to ship the official hardware-permission units/rules.
rpm -ql z13ctl | grep -E '/udev/rules.d/.*\.rules$'
# Ship vendor wants links in /usr, not mutable /etc or home directories.
install -d /usr/lib/systemd/system/multi-user.target.wants \
    /usr/lib/systemd/user/sockets.target.wants \
    /usr/lib/systemd/user/graphical-session.target.wants
ln -sfn ../z13ctl-perms.service /usr/lib/systemd/system/multi-user.target.wants/z13ctl-perms.service
# The RPM's post-install script may have enabled this under /etc during build.
if [[ -L /etc/systemd/system/multi-user.target.wants/z13ctl-perms.service ]]; then
    unlink /etc/systemd/system/multi-user.target.wants/z13ctl-perms.service
fi
for link in /etc/systemd/user/sockets.target.wants/z13ctl.socket \
    /etc/systemd/user/graphical-session.target.wants/z13ctl.service \
    /etc/systemd/user/graphical-session.target.wants/z13gui.service; do
    if [[ -L $link ]]; then unlink "$link"; fi
done
ln -sfn ../z13ctl.socket /usr/lib/systemd/user/sockets.target.wants/z13ctl.socket
for unit in z13ctl.service z13gui.service; do
    ln -sfn "../$unit" "/usr/lib/systemd/user/graphical-session.target.wants/$unit"
done

chmod +x /usr/bin/lightbar /usr/bin/bt-auto-reconnect.sh /usr/lib/systemd/system-sleep/usb-wakeup-fix
sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf
sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf
sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf
for unit in bluetooth-poweron.service bt-auto-reconnect.service; do
    ln -sfn "../$unit" "/usr/lib/systemd/system/multi-user.target.wants/$unit"
done
