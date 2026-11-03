#!/usr/bin/env python3
"""Validate the single README and its references against the current source."""
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[1]
errors = []
files = [p for p in ROOT.rglob('*.md') if '.git' not in p.parts]
if files != [ROOT / 'README.md']:
    errors.append('Keep exactly one Markdown manual: root README.md')
text = (ROOT / 'README.md').read_text()
if text.count('```') % 2:
    errors.append('README: unclosed fenced code block')
for target in re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text):
    if ':' in target or target.startswith('#'): continue
    if not (ROOT / target.split('#')[0]).exists():
        errors.append(f'Broken local link: {target}')
for section in ['Build your own ISO','Install from either kind of USB','Accounts and additional computers',
                'Architecture and module reference','Manage applications and modules','Desktop and Home Manager',
                'Gaming and graphics','Power, storage and maintenance','Commands, updates and recovery',
                'Troubleshooting','Validation and current limits']:
    if '## ' + section not in text: errors.append(f'Missing manual section: {section}')
for path in [ROOT/'modules/system/nix-fleet.sh',ROOT/'scripts/nixos_tools.py']:
    if 'docs/' in path.read_text() or 'hosts/templates/README.md' in path.read_text():
        errors.append(f'Obsolete documentation reference: {path.relative_to(ROOT)}')
expected = {
 'scripts/build-iso.sh': ['iso_tools.py'],
 'modules/iso/live-installer.nix': ['live-user-setup','liveUsername','pkgs.shadow}/bin/passwd'],
 'modules/identity.nix': ['my.user','homeDirectory'],
 'hosts/nixos/identity.nix': ['name = "ankur"'],
 'hosts/nixos/performance-tuning.nix': ['zramPercent = 90'],
}
for path, fragments in expected.items():
    source = (ROOT/path).read_text()
    for fragment in fragments:
        if fragment not in source: errors.append(f'Manual/source invariant missing in {path}: {fragment}')
for flag in ['--profile','--username','--desktop','--configure-only','--dry-run','--output-dir']:
    if flag not in text or flag not in (ROOT/'scripts/iso_tools.py').read_text(): errors.append(f'ISO interface mismatch: {flag}')
if errors:
    print('\n'.join(errors),file=sys.stderr); raise SystemExit(1)
print('Single-manual links, fences, sections and source/interface checks passed.')
