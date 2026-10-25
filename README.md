# z13-bazzite

A custom [Bazzite](https://bazzite.gg) image for the **ASUS ROG Flow Z13 (2025, GZ302EA)**, built
automatically by GitHub Actions. From the Root & Raid video
[*"ROG Flow Z13 on Linux: How I Customized Bazzite (3 Bugs I Hit)"*](https://youtu.be/DsqKCMzaBIE).
Based on [stephensedge/z13-bazzite](https://github.com/stephensedge/z13-bazzite), with
Ryzen SMU and Z13 Plus added and ASUS control tools removed. The control tools
are installed in the image, so no host RPM layering is required.
The [written guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/) has every command from it.

## What it adds on top of stock Bazzite

| Fix / tool | Why |
|---|---|
| [`z13ctl-plus`](https://github.com/terrellzen/z13ctl-plus) | hardware daemon and CLI from terrellzen's fork |
| [`z13gui-plus`](https://github.com/aic0d3r/z13gui-plus) | compatible graphical controls |
| [`ryzen_smu`](https://github.com/amkillam/ryzen_smu) | kernel module required for Strix Halo CPU undervolting |
| Bluetooth: power on at boot, auto-reconnect service, no autosuspend on the MT7925 adapter | mice and controllers kept dropping, especially after sleep |
| `mt7925e disable_aspm=1` | Wi-Fi power saving was crashing suspend |
| USB wakeup hook | detaching the keyboard woke the tablet straight back up |
| sensor labels | readable temperature and fan names in widgets |

## Use it

Switch an existing Bazzite install to this image, then reboot:

```bash
sudo bootc switch ghcr.io/<your-github-user>/z13-bazzite:latest
systemctl reboot
```

The image you came from stays on disk. If anything's wrong, pick it in the boot menu, or:

```bash
sudo bootc rollback && systemctl reboot
```

## Make your own

Fork this, change the `Containerfile`, push, and GitHub builds the image for you (about 8
minutes). For a signed image and a more complete starting point, use Universal Blue's official
[image-template](https://github.com/ublue-os/image-template).

## Hardware control

The build downloads the latest stable x86_64 RPM from **terrellzen/z13ctl-plus**
and **aic0d3r/z13gui-plus**, verifies each against its release checksum, and
installs both into the image. RPM dependencies, desktop entries, and units are
preserved. The release manifests are recorded under `/usr/share/z13-build`.
There is no source build or local binary patch. z13-tablet-kit and the original
z13ctl/z13gui are not installed by this build.

The installed fork's `z13ctl-plus --dry-run setup --group=wheel` generates the
same udev rules and sysfs-permissions service as privileged setup. The build
extracts those generated files into `/usr/lib/udev/rules.d` and
`/usr/lib/systemd/system`, and fails if the setup output format changes. It does
not run live udev triggers or write setup overrides into the host's `/etc`.
The permissions service applies access to live sysfs at boot, including Ryzen
SMU. Its enablement and the CLI/GUI user-service links also live under `/usr`.

Hardware controls are available to existing `wheel` administrators. This avoids
changing account membership on the host. Check `id -nG` to confirm your session
includes `wheel`. The image installs no first-time permission assistant and does
not need `sudo z13ctl-plus setup` after boot. Running that command manually would
create persistent `/etc` overrides and defeat this deployment's cleanup model.

The ASUS Linux COPR, asusctl, ROG Control Center, and the original fork's asusd
lightbar reset workaround are excluded. If stock Bazzite includes the ASUS
control packages, the build removes them to avoid competing hardware daemons.

Ryzen SMU is compiled from amkillam's Strix Halo fork against the image's exact
kernel and loaded at boot. Matching kernel-devel is installed if necessary;
the build fails if it cannot compile for that kernel. Undervolting is optional
and can be configured through z13gui-plus or z13ctl-plus; this image does not
apply an offset.

The full image build, keyboard hotplug, side button, and Ryzen SMU loading still
need validation on the Z13. Keep a working deployment available.

## Notes

- Kernel parameters are **not** in the image. They're per-machine (`rpm-ostree kargs`) and survive
  image updates. This tablet needs some for display stability; the
  [guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/#bug-1-a-black-screen-at-full-brightness) has the exact ones.
- Hardware-specific: the fixes were developed and tested on a GZ302EA. On other hardware, keep the method and change
  the fixes.

## Updating and earlier test installs

New image builds resolve the latest stable RPM releases. To bypass the release
layer cache explicitly, change the `Z13_RELEASE_REFRESH` build argument. After
a published build, use `sudo bootc upgrade` and reboot.

If you previously layered test RPMs, remove their layer requests before switching
to this build; an installed layer may conflict with the image's copies. Review
`rpm-ostree status` for the exact names. Manually installed tools, per-user
services, and older `/etc/udev/rules.d/99-z13ctl-plus.rules` or
`/etc/systemd/system/z13ctl-plus-perms.service` can override image defaults and
need separate review. This build does not delete existing host customizations.

## Return to stock stable

To return to the stock image used as this build's base:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

The image's Z13 Plus RPMs, generated hardware permissions, service links,
Bluetooth helpers, and Ryzen SMU module are removed when booting stock stable
(unless stock ships its own versions). Stock may restore its own ASUS tools.
Build-time
configuration under `/etc` follows bootc's merge rules: unchanged image defaults
are replaced, while local edits can persist.

A rebase does **not** erase your home directory, local group membership, or
machine kernel arguments. Earlier setup's `users` membership, desktop
shortcut, and `~/.local/state/z13-setup` marker can remain, as can Z13 Plus
preferences and Plasma display settings. They are not system installs. Remove
these separately if wanted; only remove `users` membership if setup added it and
you do not need it elsewhere. Any manually installed tools or user service
overrides also need separate cleanup. Layered RPMs are separate from the image:
remove test packages with `rpm-ostree uninstall <package-names>` and reboot when
finished; do not assume a rebase removes requested layers.
