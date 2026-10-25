# Custom Bazzite image for ASUS ROG Flow Z13 (2025, GZ302EA — Strix Halo).
# Original z13ctl + z13gui, Ryzen SMU, and the original fork's hardware fixes.

# 1. Start from stock Bazzite.
FROM ghcr.io/ublue-os/bazzite:stable

# 2. Keep the original fork's Bluetooth, Wi-Fi, USB wakeup, and sensor fixes.
COPY scripts/lightbar /usr/bin/lightbar
COPY scripts/bluetooth-poweron.service /usr/lib/systemd/system/bluetooth-poweron.service
COPY scripts/bt-auto-reconnect.sh /usr/bin/bt-auto-reconnect.sh
COPY scripts/bt-auto-reconnect.service /usr/lib/systemd/system/bt-auto-reconnect.service
COPY scripts/99-bt-nosuspend.rules /usr/lib/udev/rules.d/99-bt-nosuspend.rules
COPY scripts/mt7925e.conf /usr/lib/modprobe.d/mt7925e.conf
COPY scripts/btusb.conf /usr/lib/modprobe.d/btusb.conf
COPY scripts/usb-wakeup-fix /usr/lib/systemd/system-sleep/usb-wakeup-fix
COPY scripts/gz302ea-sensors.conf /etc/sensors.d/gz302ea.conf

# Copy installation scripts into the build image.
COPY scripts/install-z13-tools.sh /usr/libexec/z13-build/install-z13-tools.sh
COPY scripts/build-ryzen-smu.sh /usr/libexec/z13-build/build-ryzen-smu.sh
COPY scripts/configure-z13-image.sh /usr/libexec/z13-build/configure-z13-image.sh
RUN rpm-ostree install \
    git curl jq gcc make elfutils-libelf-devel \
    gtk4 gtk4-layer-shell kscreen glib2 \
    kdialog polkit libuser xdg-user-dirs \
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

# 4. Install the original upstream CLI and GUI (refresh arg bypasses cache).
ARG Z13_RELEASE_REFRESH=0
RUN echo "Z13 release refresh: ${Z13_RELEASE_REFRESH}" \
    && bash /usr/libexec/z13-build/install-z13-tools.sh \
    && ostree container commit

# 5. Build the Ryzen SMU module for this image's kernel.
RUN bash /usr/libexec/z13-build/build-ryzen-smu.sh \
    && ostree container commit

# 6. Enable Z13 and Bluetooth services.
RUN bash /usr/libexec/z13-build/configure-z13-image.sh \
    && rm -rf /usr/libexec/z13-build \
    && ostree container commit
