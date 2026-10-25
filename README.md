# z13-bazzite

A custom [Bazzite](https://bazzite.gg) image for the **ASUS ROG Flow Z13 (2025, GZ302EA)**, built
automatically by GitHub Actions. From the Root & Raid video
[*"ROG Flow Z13 on Linux: How I Customized Bazzite (3 Bugs I Hit)"*](https://youtu.be/DsqKCMzaBIE).
Based on [stephensedge/z13-bazzite](https://github.com/stephensedge/z13-bazzite), with
the original z13gui and Ryzen SMU added and asusctl / ROG Control Center removed.
The [written guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/) has every command from it.

## What it adds on top of stock Bazzite

| Fix / tool | Why |
|---|---|
| [`z13ctl`](https://github.com/dahui/z13ctl) + [`z13gui`](https://github.com/dahui/z13gui) | original upstream hardware controls and graphical interface |
| [`ryzen_smu`](https://github.com/amkillam/ryzen_smu) | kernel module required for Strix Halo CPU undervolting |
| `lightbar` | rear RGB control: `lightbar purple` |
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

The image installs the latest stable x86_64 RPMs from **dahui/z13ctl** and
**dahui/z13gui**, including their permission rules and services. It does not
include Plus, z13-tablet-kit, the ASUS Linux COPR, asusctl, or ROG Control Center.
The original fork's asusd lightbar unbind/rebind workaround is also removed.
The side button uses the original daemon's shared input watcher; no local
controller patch or `--no-button` workaround is applied.

Ryzen SMU is compiled from amkillam's Strix Halo fork against the image's exact
kernel and loaded at boot. Matching kernel-devel is installed if necessary;
the build fails if it cannot compile for that kernel. Undervolting is optional
and must be configured in z13gui or z13ctl; this image does not apply an offset.

The image build and keyboard hotplug / side button / undervolting behavior still
need validation on the Z13. Keep a working deployment available.

## Notes

- Kernel parameters are **not** in the image. They're per-machine (`rpm-ostree kargs`) and survive
  image updates. This tablet needs some for display stability; the
  [guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/#bug-1-a-black-screen-at-full-brightness) has the exact ones.
- Hardware-specific: the fixes were developed and tested on a GZ302EA. On other hardware, keep the method and change
  the fixes.

## First-time hardware permissions

On your first KDE login, open **Z13 First-Time Setup** on the desktop or in the
application menu. Choose **Configure permissions** and authenticate with KDE.
The assistant adds only your local account to `users`, which z13ctl and
z13gui require. Log out and log back in afterward.

You may move or copy the launcher to Documents; it uses the installed program's
absolute path. The assistant is safe to run again. Deleting the desktop shortcut
will not cause it to return on later logins. If your desktop is disabled or cannot
accept the shortcut, use the application menu.

The graphical assistant runs as your user. Only the group helper runs through
Polkit, with administrator authentication. It uses libuser's local files/shadow
backends to create an `/etc/group` entry with the vendor GID when `users` lives
only in `/usr/lib/group`, preserves vendor and local members, and appends your
account. It never writes to `/usr` at runtime or changes sudoers. The KDE
autostart hook runs without privileges and records its one-time offer under
`${XDG_STATE_HOME:-~/.local/state}/z13-setup`.

## Return to stock stable

To return to the stock image used as this build's base:

```bash
sudo bootc switch ghcr.io/ublue-os/bazzite:stable
systemctl reboot
```

The installed Z13 tools, vendor service links, udev rules, and Ryzen SMU module
live in the image and are removed when booting stock stable (unless stock ships
its own versions). Stock may restore its own asusctl / ROG tools. Build-time
configuration under `/etc` follows bootc's merge rules: unchanged image defaults
are replaced, while local edits can persist.

A rebase does **not** erase your home directory, local group membership, or
machine kernel arguments. The first-time setup's `users` membership, desktop
shortcut, and `~/.local/state/z13-setup` marker can remain, as can z13ctl/z13gui
preferences and Plasma display settings. They are not system installs. Remove
these separately if wanted; only remove `users` membership if setup added it and
you do not need it elsewhere. Any manually installed tools or user service
overrides also need separate cleanup. Do not run upstream `sudo z13ctl setup` or
`make install-service` on the host: the image already supplies those files.
