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

# 3. Install required dependencies for Z13 controls, tablet mode, and Ryzen SMU.
RUN rpm-ostree install \
    git curl jq gcc make elfutils-libelf-devel \
    python3-evdev iio-sensor-proxy gtk4 gtk4-layer-shell \
    kscreen glib2 \
    && rpm-ostree cleanup -m \
    && ostree container commit

# 4. Install the latest z13ctl-plus and z13gui-plus RPM releases.
#    Each image rebuild checks GitHub for the latest stable releases.
ARG Z13_RELEASE_REFRESH=0
RUN echo "Release refresh: ${Z13_RELEASE_REFRESH}" \
    && mkdir -p /tmp/z13-packages \
    && for project in z13ctl-plus z13gui-plus; do \
        api="https://api.github.com/repos/aic0d3r/${project}/releases/latest"; \
        url="$(curl -fsSL "$api" | jq -r '[.assets[].browser_download_url | select(endswith(".rpm")) | select(test("x86_64|amd64"))][0] // empty')"; \
        test -n "$url" || exit 1; \
        curl -fL --retry 3 "$url" -o "/tmp/z13-packages/${project}.rpm" || exit 1; \
    done \
    && rpm-ostree install /tmp/z13-packages/z13ctl-plus.rpm /tmp/z13-packages/z13gui-plus.rpm \
    && rpm-ostree cleanup -m \
    && rm -rf /tmp/z13-packages \
    && ostree container commit

# 5. Install the latest z13-tablet-kit for posture detection, rotation, and touch gestures.
#    Install system-wide and adjust its user services for the new paths.
RUN git clone --depth 1 https://github.com/aic0d3r/z13-tablet-kit.git /tmp/z13-tablet-kit \
    && mkdir -p /usr/lib/z13-tablet-kit /usr/lib/systemd/user /usr/lib/udev/rules.d \
    && install -m755 /tmp/z13-tablet-kit/bin/dock /usr/lib/z13-tablet-kit/dock \
    && install -m755 /tmp/z13-tablet-kit/bin/z13-tablet-switch /usr/lib/z13-tablet-kit/z13-tablet-switch \
    && install -m755 /tmp/z13-tablet-kit/bin/z13-touch-scroll /usr/lib/z13-tablet-kit/z13-touch-scroll \
    && cp /tmp/z13-tablet-kit/systemd/*.service /usr/lib/systemd/user/ \
    && sed -i 's#%h/.local/bin/#/usr/lib/z13-tablet-kit/#g' /usr/lib/systemd/user/z13-tablet-switch.service /usr/lib/systemd/user/z13-touch-scroll.service \
    && cp /tmp/z13-tablet-kit/udev/*.rules /usr/lib/udev/rules.d/ \
    && mkdir -p /usr/lib/systemd/user/graphical-session.target.wants \
    && ln -s ../z13-tablet-switch.service /usr/lib/systemd/user/graphical-session.target.wants/z13-tablet-switch.service \
    && ln -s ../z13-touch-scroll.service /usr/lib/systemd/user/graphical-session.target.wants/z13-touch-scroll.service \
    && rm -rf /tmp/z13-tablet-kit \
    && ostree container commit

# 6. Build the Strix Halo Ryzen SMU driver against Bazzite's installed kernel.
#    Uses amkillam/ryzen_smu instead of the original upstream driver.
#    Matching kernel development files must exist in the base image.
RUN set -eux; \
    kernel="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n 1)"; \
    test -n "$kernel"; \
    test -d "/usr/src/kernels/$kernel"; \
    git clone --depth 1 https://github.com/amkillam/ryzen_smu.git /tmp/ryzen_smu; \
    make -C /tmp/ryzen_smu TARGET="$kernel"; \
    test -f /tmp/ryzen_smu/ryzen_smu.ko; \
    install -Dm644 /tmp/ryzen_smu/ryzen_smu.ko "/usr/lib/modules/$kernel/updates/ryzen_smu.ko"; \
    depmod -a "$kernel"; \
    mkdir -p /usr/lib/modules-load.d; \
    printf 'ryzen_smu\n' > /usr/lib/modules-load.d/ryzen_smu.conf; \
    rm -rf /tmp/ryzen_smu; \
    ostree container commit

# 7. Configure Bluetooth, enable hardware fixes, and finalize the image.
RUN chmod +x /usr/bin/bt-auto-reconnect.sh /usr/lib/systemd/system-sleep/usb-wakeup-fix \
    && sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf \
    && sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf \
    && systemctl enable bluetooth-poweron.service \
    && systemctl enable bt-auto-reconnect.service \
    && ostree container commit
