# z13-bazzite

A custom [Bazzite](https://bazzite.gg) image for the **ASUS ROG Flow Z13 (2025, GZ302EA)**, built
automatically by GitHub Actions. From the Root & Raid video
[*"ROG Flow Z13 on Linux: How I Customized Bazzite (3 Bugs I Hit)"*](https://youtu.be/DsqKCMzaBIE).
The [written guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/) has every command from it.

## What it adds on top of stock Bazzite

| Fix / tool | Why |
|---|---|
| `asusctl` + ROG Control Center | fans, power profiles, keyboard (asus-linux COPR) |
| [`z13ctl`](https://github.com/dahui/z13ctl) + `lightbar` | control the rear RGB light bar: `lightbar purple` |
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

## Differences from the image on my own tablet

This is the public, gaming-only version of the image I run every day. The fixes are the same;
two things are deliberately tighter here:

- **RGB device access** uses `uaccess` (only the person logged in at the tablet) instead of making
  the devices world-writable. On my tablet I also drive the light bar over SSH, which `uaccess`
  doesn't allow; if you need that, it's your call to loosen it.
- **No polkit rule** letting the `wheel` group restart Bluetooth without a password. The
  reconnect helper doesn't need it.

**Honest status:** this public image is built by GitHub Actions from the same fixes, but the public
build itself hasn't been booted on hardware yet. Keep your previous deployment until you've
rebooted into it and checked it.

## Notes

- Kernel parameters are **not** in the image. They're per-machine (`rpm-ostree kargs`) and survive
  image updates. This tablet needs some for display stability; the
  [guide](https://rootandraid.com/guides/custom-bazzite-rog-flow-z13/#bug-1-a-black-screen-at-full-brightness) has the exact ones.
- Hardware-specific: the fixes were developed and tested on a GZ302EA. On other hardware, keep the method and change
  the fixes.

## First-time hardware permissions

On your first KDE login, open **Z13 First-Time Setup** on the desktop or in the
application menu. Choose **Configure permissions** and authenticate with KDE.
The assistant adds only your local account to `users`, which z13ctl-plus and
z13gui-plus require. Log out and log back in afterward.

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
