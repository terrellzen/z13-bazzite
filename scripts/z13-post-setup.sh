#!/usr/bin/env bash
set -euo pipefail

export PATH=/usr/bin:/usr/sbin
command -v kdialog >/dev/null || { echo 'ERROR: KDE kdialog is required.' >&2; exit 1; }
error() { kdialog --title 'Z13 First-Time Setup' --error "$1"; exit 1; }
(( EUID != 0 )) || error 'Open this assistant as your normal desktop user, without sudo.'
user=$(id -un)
configured() { [[ " $(id -nG "$user") " == *' users '* ]]; }
finished() {
    kdialog --title 'Z13 First-Time Setup' --msgbox "$1

Log out and log back in for hardware permissions to take effect in your session.

You may move or copy this launcher to Documents for future use. It will continue to work there."
}
if configured; then
    finished 'Your account already belongs to the users group. No changes were needed.'
    exit 0
fi
if ! kdialog --title 'Z13 First-Time Setup' --yes-label 'Configure permissions' --no-label 'Cancel' --yesno \
    'z13ctl and z13gui need your account to belong to the users group to access Z13 hardware.

Configure permissions for your account? KDE will request administrator authentication. Afterward, log out and log back in.'; then
    exit 0
fi
if output=$(pkexec --disable-internal-agent /usr/libexec/z13-configure-permissions 2>&1); then
    configured || error 'The permission change could not be verified. Please try again or contact your system administrator.'
    finished 'Hardware permissions configured successfully.'
else
    status=$?
    if [[ $status == 126 ]]; then
        error 'Administrator authentication was canceled. No further changes were made.'
    fi
    error "Could not configure hardware permissions. Administrator authentication and a running KDE authentication agent are required.

${output:-The permission helper failed. Please try again.}"
fi
