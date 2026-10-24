#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin
fail() { echo "ERROR: $*" >&2; exit 1; }
(( EUID == 0 )) || fail 'This helper must be invoked through pkexec.'
[[ $# == 0 && ${PKEXEC_UID:-} =~ ^[0-9]+$ && $PKEXEC_UID != 0 ]] || fail 'No valid invoking user.'
# Resolve only local accounts, never a username supplied by the launcher or environment.
record=$(awk -F: -v uid="$PKEXEC_UID" '$3 == uid { print; exit }' /etc/passwd)
[[ -n $record ]] || fail 'The invoking account is not a local user.'
IFS=: read -r user _ uid _ _ _ shell <<< "$record"
uid_min=$(awk '$1 == "UID_MIN" {print $2; exit}' /etc/login.defs)
uid_min=${uid_min:-1000}
[[ $uid_min =~ ^[0-9]+$ ]] || fail 'Invalid UID_MIN configuration.'
(( uid >= uid_min && uid != 65534 )) || fail 'A regular local user is required.'
[[ $shell != */nologin && $shell != */false ]] || fail 'A login account is required.'
# Serialize this assistant; libuser also locks the account files during updates.
exec 9>/run/z13-configure-permissions.lock
flock -x 9
if [[ " $(id -nG "$user") " == *' users '* ]]; then
    exit 0
fi
# libuser uses the local files/shadow backends, so it can create an /etc entry
# even when NSS already sees the vendor group in immutable /usr/lib/group.
# Pin the backends rather than relying on a site's libuser configuration.
export LIBUSER_CONF=/usr/share/z13-setup/libuser.conf
vendor=$(awk -F: '$1 == "users" {print; exit}' /usr/lib/group 2>/dev/null || true)
local_group=$(awk -F: '$1 == "users" {print; exit}' /etc/group)
if [[ -z $local_group ]]; then
    [[ -n $vendor ]] || fail 'The users group is missing from both /etc/group and /usr/lib/group.'
    IFS=: read -r _ _ gid _ <<< "$vendor"
    [[ $gid =~ ^[0-9]+$ ]] || fail 'Invalid vendor users group ID.'
    lgroupadd --gid "$gid" users || fail 'Could not create the local users group entry.'
    local_group=$(awk -F: '$1 == "users" {print; exit}' /etc/group)
fi
IFS=: read -r _ _ gid _ <<< "$local_group"
if [[ -n $vendor ]]; then
    IFS=: read -r _ _ vendor_gid vendor_members <<< "$vendor"
    [[ $gid == "$vendor_gid" ]] || fail 'Local and vendor users group IDs differ; ask your administrator to resolve this.'
    # Preserve vendor members when the /etc entry shadows /usr/lib/group.
    if [[ -n $vendor_members ]]; then
        lgroupmod --member-add "$vendor_members" users || fail 'Could not preserve vendor group members.'
    fi
fi
lgroupmod --member-add "$user" users || fail "Could not add $user to the users group."
[[ " $(id -nG "$user") " == *' users '* ]] || fail 'Group membership could not be verified.'
