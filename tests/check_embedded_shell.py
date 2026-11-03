#!/usr/bin/env python3
"""Syntax/lint the two new embedded live-media scripts with fixture Nix values."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'modules/iso/live-installer.nix').read_text()
markers = [("    text = ''\n", "\n    '';"),
           ('  livePassword = pkgs.writeShellScript "live-user-password" \'\'\n', "\n  '';" )]
with tempfile.TemporaryDirectory(prefix='iso-shell-check-') as temp:
    for i, (start, finish) in enumerate(markers):
        begin = source.index(start) + len(start)
        end = source.index(finish, begin)
        text = source[begin:end].replace("''${TMPDIR:-/tmp}", '${TMPDIR:-/tmp}')
        text = re.sub(r'\$\{pkgs\.[a-zA-Z0-9_-]+\}', '/nix/store/test-tool', text)
        text = text.replace('${isoSource}', '/nix/store/test-source')
        text = text.replace('${lib.escapeShellArg cfg.liveUsername}', "'alice'")
        path = Path(temp) / f'embedded-{i}.sh'
        path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + text + '\n')
        subprocess.run(['bash','-n',str(path)],check=True)
        if shutil.which('shellcheck'):
            subprocess.run(['shellcheck',str(path)],check=True)
print('Both embedded live-media shell snippets passed syntax and available lint checks (fixture substitution, not execution).')
