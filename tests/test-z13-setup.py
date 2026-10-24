#!/usr/bin/env python3
"""Integration checks using real account tools in an unprivileged bubblewrap sandbox."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    etc = root / 'etc'
    etc.mkdir()
    (etc / 'passwd').write_text('root:x:0:0:root:/root:/bin/bash\nalex:x:1000:1000::/home/alex:/bin/bash\nother:x:1001:1001::/home/other:/bin/bash\n')
    (etc / 'group').write_text('root:x:0:\nwheel:x:10:alex,other\nalex:x:1000:\nother:x:1001:\n')
    (etc / 'gshadow').write_text('root:!::\nwheel:!::alex,other\nalex:!::\nother:!::\n')
    (etc / 'shadow').write_text('')
    (etc / 'login.defs').write_text('UID_MIN 1000\n')
    (etc / 'nsswitch.conf').write_text('passwd: files\ngroup: files [SUCCESS=merge] altfiles\nshadow: files\n')
    vendor = root / 'vendor-group'
    vendor.write_text('users:x:100:other\n')
    base = ['bwrap', '--unshare-all', '--ro-bind', '/usr', '/usr',
            '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/sbin', '/sbin',
            '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib64', '/lib64',
            '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/run',
            '--bind', str(etc), '/etc', '--ro-bind', str(vendor), '/usr/lib/group',
            '--tmpfs', '/usr/share', '--dir', '/usr/share/z13-setup',
            '--ro-bind', str(repo / 'scripts/z13-setup-libuser.conf'), '/usr/share/z13-setup/libuser.conf',
            '--ro-bind', str(repo / 'scripts/z13-configure-permissions.sh'), '/helper',
            '--uid', '0', '--gid', '0', '--setenv', 'PKEXEC_UID', '1000']
    def helper(*args, ok=True, prefix=()):
        result = subprocess.run(base + list(prefix) + ['/bin/bash', '/helper', *args], capture_output=True, text=True)
        assert (result.returncode == 0) == ok, result.stderr
    helper()
    group = (etc / 'group').read_text()
    assert 'wheel:x:10:alex,other\n' in group
    assert set(next(x for x in group.splitlines() if x.startswith('users:')).split(':')[3].split(',')) == {'alex', 'other'}
    before = {p.name: p.read_bytes() for p in etc.iterdir() if p.is_file()}
    helper()
    assert before == {p.name: p.read_bytes() for p in etc.iterdir() if p.is_file()}
    helper('other', ok=False)
    helper(ok=False, prefix=['/usr/bin/env', 'PKEXEC_UID=0'])
    helper(ok=False, prefix=['/usr/bin/env', 'PKEXEC_UID=9999'])
    # An existing writable users entry retains its members as well.
    other_groups = ''.join(line + '\n' for line in group.splitlines() if not line.startswith('users:'))
    (etc / 'group').write_text(other_groups + 'users:x:100:localmember\n')
    shadow_groups = ''.join(line + '\n' for line in (etc / 'gshadow').read_text().splitlines() if not line.startswith('users:'))
    (etc / 'gshadow').write_text(shadow_groups + 'users:!::localmember\n')
    helper()
    assert set(next(x for x in (etc / 'group').read_text().splitlines() if x.startswith('users:')).split(':')[3].split(',')) == {'alex', 'other', 'localmember'}
    (etc / 'group').write_text(other_groups + 'users:x:101:other\n')
    before_conflict = (etc / 'group').read_bytes()
    helper(ok=False)
    assert (etc / 'group').read_bytes() == before_conflict
    assert vendor.read_text() == 'users:x:100:other\n'
    print('PASS: real libuser split-group creation, preserved memberships, repeated execution, and caller validation; /usr read-only')

with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    (home / '.config').mkdir()
    desktop = home / 'Schreibtisch'
    desktop.mkdir()
    (home / '.config/user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME/Schreibtisch"\n')
    base = ['bwrap', '--unshare-all', '--ro-bind', '/usr', '/usr',
            '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/lib', '/lib',
            '--symlink', 'usr/lib64', '/lib64', '--dev', '/dev',
            '--tmpfs', '/usr/share', '--dir', '/usr/share/applications',
            '--ro-bind', str(repo / 'scripts/z13-first-time-setup.desktop'), '/usr/share/applications/z13-first-time-setup.desktop',
            '--ro-bind', str(repo / 'scripts/z13-desktop-setup.sh'), '/offer',
            '--bind', str(home), '/home/alex', '--setenv', 'HOME', '/home/alex',
            '--unsetenv', 'XDG_STATE_HOME', '--unsetenv', 'XDG_CONFIG_HOME',
            '/bin/bash', '/offer']
    def offer():
        subprocess.run(base, check=True)
    offer()
    target = desktop / 'z13-first-time-setup.desktop'
    assert target.read_bytes() == (repo / 'scripts/z13-first-time-setup.desktop').read_bytes()
    assert os.access(target, os.X_OK)
    target.unlink()
    offer()
    assert not target.exists()
    marker = home / '.local/state/z13-setup/desktop-offered'
    marker.unlink()
    target.write_text('existing file')
    offer()
    assert target.read_text() == 'existing file'
    marker.unlink()
    target.unlink()
    (home / '.config/user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME"\n')
    offer()
    assert not (home / 'z13-first-time-setup.desktop').exists()
    assert marker.exists()
    print('PASS: localized desktop, executable shortcut, deletion respected, no overwrite, disabled desktop')
