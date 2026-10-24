# Custom Bazzite image for ASUS ROG Flow Z13 (2025, GZ302EA — Strix Halo).
# Includes z13ctl-plus, z13gui-plus, z13-tablet-kit, Ryzen SMU, and hardware fixes.

# 1. Start from stock Bazzite.
FROM ghcr.io/ublue-os/bazzite:stable

# 2. Keep the Bluetooth, Wi-Fi, USB wakeup, and sensor fixes.
COPY scripts/bluetooth-poweron.service /etc/systemd/system/bluetooth-poweron.service
COPY scripts/bt-auto-reconnect.sh /usr/bin/bt-auto-reconnect.sh
COPY scripts/bt-auto-reconnect.service /etc/systemd/system/bt-auto-reconnect.service
COPY scripts/99-bt-nosuspend.rules /etc/udev/rules.d/99-bt-nosuspend.rules
COPY scripts/mt7925e.conf /etc/modprobe.d/mt7925e.conf
COPY scripts/btusb.conf /etc/modprobe.d/btusb.conf
COPY scripts/usb-wakeup-fix /usr/lib/systemd/system-sleep/usb-wakeup-fix
COPY scripts/gz302ea-sensors.conf /etc/sensors.d/gz302ea.conf

# Copy installation scripts into the build image.
COPY scripts/install-z13-plus.sh /usr/libexec/z13-build/install-z13-plus.sh
COPY scripts/install-tablet-kit.sh /usr/libexec/z13-build/install-tablet-kit.sh
COPY scripts/build-ryzen-smu.sh /usr/libexec/z13-build/build-ryzen-smu.sh
COPY scripts/configure-z13-image.sh /usr/libexec/z13-build/configure-z13-image.sh
RUN rpm-ostree install \
    git curl jq gcc make elfutils-libelf-devel \
    python3-evdev iio-sensor-proxy gtk4 gtk4-layer-shell \
    kscreen glib2 qt6-qttools kdialog polkit libuser xdg-user-dirs \
    && rpm-ostree cleanup -m \
    && ostree container commit

# Install the unprivileged assistant, scoped Polkit helper, and KDE session hook.
COPY scripts/z13-post-setup.sh /usr/bin/z13-post-setup
COPY scripts/z13-configure-permissions.sh /usr/libexec/z13-configure-permissions
COPY scripts/z13-desktop-setup.sh /usr/libexec/z13-desktop-setup
COPY scripts/z13-first-time-setup.desktop /usr/share/applications/z13-first-time-setup.desktop
COPY scripts/z13-desktop-setup.desktop /etc/xdg/autostart/z13-desktop-setup.desktop
COPY scripts/z13-setup-libuser.conf /usr/share/z13-setup/libuser.conf
COPY scripts/org.z13.configure-permissions.policy /usr/share/polkit-1/actions/org.z13.configure-permissions.policy

# 4. Fetch the latest stable Z13 Plus RPMs (refresh build arg to bypass cache).
ARG Z13_RELEASE_REFRESH=0
RUN echo "Z13 release refresh: ${Z13_RELEASE_REFRESH}" \
    && bash /usr/libexec/z13-build/install-z13-plus.sh \
    && ostree container commit

# 5. Install the tablet kit and the matching Ryzen SMU kernel module.
ARG Z13_TABLET_REFRESH=0
RUN echo "Tablet kit refresh: ${Z13_TABLET_REFRESH}" \
    && bash /usr/libexec/z13-build/install-tablet-kit.sh \
    && ostree container commit
RUN bash /usr/libexec/z13-build/build-ryzen-smu.sh \
    && ostree container commit

# 6. Set up services, Fedora qdbus compatibility, and Bluetooth.
RUN bash /usr/libexec/z13-build/configure-z13-image.sh \
    && rm -rf /usr/libexec/z13-build \
    && ostree container commit
