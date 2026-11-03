#!/usr/bin/env python3
"""Optional Tree-sitter syntax checks; not Nix evaluation or a build."""
from pathlib import Path
import importlib.util
import sys
try:
    from tree_sitter import Language, Parser
    import tree_sitter_nix
except ImportError:
    print('Tree-sitter unavailable; use nix-instantiate or install requirements-audit.txt.')
    raise SystemExit(77)
root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_nix.language()))
files = list(root.rglob('*.nix')) + [root / 'hosts/templates/new-host.nix.example']
errors = []
for path in files:
    if '.git' not in path.parts and parser.parse(path.read_bytes()).root_node.has_error:
        errors.append(str(path.relative_to(root)))
module_spec = importlib.util.spec_from_file_location('nixos_syntax_tools', root / 'scripts/nixos_tools.py')
tools = importlib.util.module_from_spec(module_spec)
sys.modules[module_spec.name] = tools
module_spec.loader.exec_module(tools)
count = 0
for gpu in tools.GRAPHICS:
    hybrid = gpu.endswith('-nvidia')
    for boot, fs in [('uefi', 'btrfs'), ('legacy', 'ext4')]:
        host = tools.Host('syntax-only', 'tester', graphics=gpu, boot=boot,
                          disk='/dev/sdz' if boot == 'legacy' else '',
                          integrated_bus_id='PCI:5@0:0:0' if hybrid else '',
                          nvidia_bus_id='PCI:1@0:0:0' if hybrid else '')
        if parser.parse(tools.render_host(host, fs).encode()).root_node.has_error:
            errors.append(f'generated:{gpu}:{boot}:{fs}')
        count += 1
if errors:
    print('Nix syntax errors:', errors, file=sys.stderr)
    raise SystemExit(1)
print(f'Tree-sitter syntax passed: {len(files)} Nix files/templates and {count} generated variants. No evaluation/build performed.')
