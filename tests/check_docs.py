#!/usr/bin/env python3
"""Check local Markdown links and catalog coverage; no network required."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
files = [p for p in ROOT.rglob('*.md') if '.git' not in p.parts]
for page in files:
    text = page.read_text()
    for target in re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text):
        if ':' in target or target.startswith('#'):
            continue
        path = (page.parent / target.split('#')[0]).resolve()
        if not path.exists():
            errors.append(f'{page.relative_to(ROOT)}: broken link {target}')
    if text.count('```') % 2:
        errors.append(f'{page.relative_to(ROOT)}: unclosed fenced code block')
index = (ROOT / 'docs/README.md').read_text()
for p in files:
    if p.parent == ROOT / 'docs' and p.name != 'README.md' and p.name not in index:
        errors.append(f'Guide missing from index: {p.name}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f'Documentation checks passed ({len(files)} Markdown files).')
