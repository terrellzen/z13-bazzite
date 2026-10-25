#!/usr/bin/env python3
"""Extract setup-generated files; fail the build if upstream output changes."""
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
destination = Path(sys.argv[2])
files = (
    ("/etc/udev/rules.d/99-z13ctl-plus.rules", "# 99-z13ctl-plus.rules", "SUBSYSTEM=="),
    ("/etc/systemd/system/z13ctl-plus-perms.service", "[Unit]", "[Service]"),
)
for path, prefix, required in files:
    start = f"Would write {path}:\n\n"
    if text.count(start) != 1:
        raise SystemExit(f"Unexpected setup output for {path}")
    content, separator, _ = text.split(start, 1)[1].partition("Would run:")
    content = content.rstrip() + "\n"
    if not separator or not content.startswith(prefix) or required not in content:
        raise SystemExit(f"Incomplete generated file: {path}")
    if 'GROUP="users"' in content or "chgrp users " in content:
        raise SystemExit(f"Setup did not select the wheel group: {path}")
    expected_group = 'GROUP="wheel"' if path.endswith('.rules') else 'chgrp wheel '
    if expected_group not in content:
        raise SystemExit(f"Missing wheel permissions: {path}")
    (destination / Path(path).name).write_text(content)
