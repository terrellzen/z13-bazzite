# z13-bazzite

A custom [Bazzite](https://bazzite.gg) image for the **ASUS ROG Flow Z13 (2025, GZ302EA)**, built
automatically by GitHub Actions. From the Root & Raid video
[*"ROG Flow Z13 on Linux: How I Customized Bazzite (3 Bugs I Hit)"*](https://youtu.be/DsqKCMzaBIE).
Based on [stephensedge/z13-bazzite](https://github.com/stephensedge/z13-bazzite), with
Ryzen SMU added and ASUS control tools removed. Z13 control packages are layered
separately for testing.
The [written guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/) has every command from it.

## What it adds on top of stock Bazzite

| Fix / tool | Why |
|---|---|
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

The image does not install z13ctl, z13gui, their Plus variants, or z13-tablet-kit.
It also omits their permission assistant, desktop autostart hook, service links,
and the `lightbar` wrapper. Layer the CLI/GUI RPMs you want to test after booting
this image; their packages supply their own services and hardware permissions.
This image does not mask or disable those services, so layered packages can run.

The ASUS Linux COPR, asusctl, ROG Control Center, and the original fork's asusd
lightbar reset workaround are excluded. If stock Bazzite includes the ASUS
control packages, the build removes them to avoid competing hardware daemons.

Ryzen SMU is compiled from amkillam's Strix Halo fork against the image's exact
kernel and loaded at boot. Matching kernel-devel is installed if necessary;
the build fails if it cannot compile for that kernel. Undervolting is optional
and can be configured through your separately installed tools; this image does
not apply an offset.

The image build and Ryzen SMU loading still need validation on the Z13. Keep a working deployment available.

## Notes

- Kernel parameters are **not** in the image. They're per-machine (`rpm-ostree kargs`) and survive
  image updates. This tablet needs some for display stability; the
  [guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/#bug-1-a-black-screen-at-full-brightness) has the exact ones.
- Hardware-specific: the fixes were developed and tested on a GZ302EA. On other hardware, keep the method and change
  the fixes.

## Testing layered packages

Install your test RPMs with `sudo rpm-ostree install /path/to/cli.rpm /path/to/gui.rpm`
and reboot. Follow those packages' instructions for permissions and service
activation. The image supplies no Z13 daemon or udev rules that could conflict
with your test packages. Existing per-user services or manually installed copies
from earlier testing can still take precedence and need separate review.

## Return to stock stable

To return to the stock image used as this build's base:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

The image's Bluetooth service links, hardware rules, and Ryzen SMU module
are removed when booting stock stable (unless stock ships its own versions). Stock may restore its own asusctl / ROG tools. Build-time
configuration under `/etc` follows bootc's merge rules: unchanged image defaults
are replaced, while local edits can persist.

A rebase does **not** erase your home directory, local group membership, or
machine kernel arguments. Earlier setup's `users` membership, desktop
shortcut, and `~/.local/state/z13-setup` marker can remain, as can z13ctl/z13gui
preferences and Plasma display settings. They are not system installs. Remove
these separately if wanted; only remove `users` membership if setup added it and
you do not need it elsewhere. Any manually installed tools or user service
overrides also need separate cleanup. Layered RPMs are separate from the image:
remove test packages with `rpm-ostree uninstall <package-names>` and reboot when
finished; do not assume a rebase removes requested layers.
