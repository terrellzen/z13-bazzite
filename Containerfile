# Custom Bazzite image for ASUS ROG Flow Z13 (2025, GZ302EA — Strix Halo).
# Ryzen SMU and hardware fixes; Z13 control tools are layered separately.

# 1. Start from stock Bazzite.
FROM ghcr.io/ublue-os/bazzite:stable

# 2. Keep the original fork's Bluetooth, Wi-Fi, USB wakeup, and sensor fixes.
COPY scripts/bluetooth-poweron.service /usr/lib/systemd/system/bluetooth-poweron.service
COPY scripts/bt-auto-reconnect.sh /usr/bin/bt-auto-reconnect.sh
COPY scripts/bt-auto-reconnect.service /usr/lib/systemd/system/bt-auto-reconnect.service
COPY scripts/99-bt-nosuspend.rules /usr/lib/udev/rules.d/99-bt-nosuspend.rules
COPY scripts/mt7925e.conf /usr/lib/modprobe.d/mt7925e.conf
COPY scripts/btusb.conf /usr/lib/modprobe.d/btusb.conf
COPY scripts/usb-wakeup-fix /usr/lib/systemd/system-sleep/usb-wakeup-fix
COPY scripts/gz302ea-sensors.conf /etc/sensors.d/gz302ea.conf

# Copy installation scripts into the build image.
COPY scripts/build-ryzen-smu.sh /usr/libexec/z13-build/build-ryzen-smu.sh
COPY scripts/configure-z13-image.sh /usr/libexec/z13-build/configure-z13-image.sh
RUN rpm-ostree install git gcc make elfutils-libelf-devel \
    && rpm-ostree cleanup -m \
    && ostree container commit

# 3. Build the Ryzen SMU module for this image's kernel.
RUN bash /usr/libexec/z13-build/build-ryzen-smu.sh \
    && ostree container commit

# 4. Remove competing ASUS tools and enable Bluetooth services.
RUN bash /usr/libexec/z13-build/configure-z13-image.sh \
    && rm -rf /usr/libexec/z13-build \
    && ostree container commit
