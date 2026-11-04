"""Fail-closed source preparation for the live ISO builder, not a secrets manager."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
from nixos_tools import SafetyError, require

ROOTS = {'assets', 'home', 'hosts', 'iso-configs', 'lib', 'modules', 'scripts', 'tests'}
ROOT_FILES = {'flake.nix', 'flake.lock', 'README.md', '.gitignore'}
DENIED_DIRS = {'.git', '.ssh', '.gnupg', '.aws', '.azure', '.config', 'private-keys-v1.d',
               'secrets', 'credentials', 'node_modules', '__pycache__'}
DENIED_SUFFIXES = {'.key', '.pem', '.p12', '.pfx', '.gpg', '.asc', '.age', '.kdbx'}
KEY_HEADER = re.compile(rb'^-----BEGIN (?:[A-Z0-9 ]*PRIVATE KEY|PGP PRIVATE KEY BLOCK)-----\r?$', re.M)
HASH_LITERAL = re.compile(rb'\$(?:y|6|5|2[aby])\$[./A-Za-z0-9]+\$[./A-Za-z0-9$]{20,}')
TOKEN = re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{60,}|AKIA[A-Z0-9]{16})')
URL_CREDENTIAL = re.compile(rb'https?://[^/\s\x22\x27<>]*@|[?&](?:access_token|password|secret)=[^\s\x22\x27<>]+', re.I)


def sensitive_name(path):
    path = PurePosixPath(path)
    name = path.name
    return (bool(set(path.parts) & DENIED_DIRS) or name in {'.env', 'credentials', 'secring.gpg', 'authorized_keys', 'known_hosts'}
            or name.startswith('.env.') or path.suffix.lower() in DENIED_SUFFIXES
            or re.fullmatch(r'(?:id_(?:rsa|dsa|ecdsa|ed25519)|ssh_host_.*_key)(?:\.pub)?', name) is not None)


def tracked(repo):
    process = subprocess.run(['git', 'ls-files', '--stage', '-z'], cwd=repo, capture_output=True, check=False)
    require(process.returncode == 0, 'ISO source must be a readable Git checkout.')
    files = []
    for record in process.stdout.split(b'\0'):
        if not record:
            continue
        info, path = record.split(b'\t', 1)
        mode, _, stage = info.decode().split()
        require(stage == '0', 'Resolve Git conflicts before preparing an ISO.')
        path = os.fsdecode(path)
        relative = PurePosixPath(path)
        require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe tracked source path.')
        require(mode in {'100644', '100755', '120000'}, f'ISO source refuses submodules: {path}')
        files.append((path, mode))
    return files


def inspect_source(repo):
    repo = Path(repo).resolve()
    records, excluded, problems = [], [], []
    entries = tracked(repo)
    modes = dict(entries)
    for name, mode in entries:
        relative = PurePosixPath(name)
        if sensitive_name(relative):
            problems.append(f'{name} (credential-like path)')
            continue
        if relative.parts[0] not in ROOTS and name not in ROOT_FILES:
            excluded.append(name)
            continue
        path = repo / name
        try:
            resolved = path.resolve(strict=True)
        except (OSError, RuntimeError) as exc:
            raise SafetyError(f'Unresolvable source path: {name}') from exc
        require(resolved.is_relative_to(repo), f'Source escapes repository: {name}')
        if mode == '120000':
            target = resolved.relative_to(repo).as_posix()
            require(target in modes and modes[target] in {'100644', '100755'} and not sensitive_name(target)
                    and (PurePosixPath(target).parts[0] in ROOTS or target in ROOT_FILES),
                    f'Symlink must resolve to a public tracked regular file: {name}')
            path, mode = resolved, modes[target]
        try:
            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        except OSError as exc:
            raise SafetyError(f'Cannot safely read ISO source: {name}') from exc
        with os.fdopen(descriptor, 'rb') as stream:
            require(stat.S_ISREG(os.fstat(stream.fileno()).st_mode), f'Not a regular source file: {name}')
            data = stream.read()
        placeholder = b'http://' + b'user:password@' + b'proxy:port/'
        url_data = b'\n'.join(line.replace(placeholder, b'http://example.invalid/')
                              if line.lstrip().startswith(b'#') else line for line in data.split(b'\n'))
        if KEY_HEADER.search(data) or HASH_LITERAL.search(data) or TOKEN.search(data) or URL_CREDENTIAL.search(url_data):
            problems.append(f'{name} (private key, password hash, token or credential-URL marker)')
            continue
        records.append((name, mode, data))
    require(not problems, 'Refusing to evaluate/build a potentially sensitive source tree:\n  ' + '\n  '.join(problems)
            + '\nMove credentials out of this flake checkout; no secret-content bypass is provided.')
    by_name = {name: data for name, _, data in records}
    require({'flake.nix', 'flake.lock', 'README.md'} <= by_name.keys(), 'Missing tracked flake.nix, flake.lock or README.md.')
    lock = json.loads(by_name['flake.lock'])
    for node in lock.get('nodes', {}).values():
        locked = node.get('locked', {})
        require(locked.get('type') != 'path', 'Local path flake inputs are not allowed in the public ISO snapshot.')
        for value in locked.values():
            if isinstance(value, str):
                require(not re.search(r'https?://[^/\s]*@|[?&](?:token|access_token|password|secret)=', value, re.I),
                        'A flake input URL contains credentials; refusing ISO preparation.')
    return records, excluded


def snapshot(repo, destination):
    records, excluded = inspect_source(repo)
    destination = Path(destination)
    require(not destination.exists(), 'Snapshot destination must be a new directory.')
    destination.mkdir(mode=0o700, parents=True)
    manifest = []
    for name, mode, data in records:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
        target.chmod(0o755 if mode == '100755' else 0o644)
        manifest.append({'path': name, 'sha256': hashlib.sha256(data).hexdigest()})
    return {'schema': 1, 'files': manifest, 'excluded_paths': excluded,
            'policy': 'Current tracked public source only; no Git history, home directories or credential-like files. Safe internal tracked-file symlinks are materialized; escaping links are refused.',
            'limits': 'Heuristic source checks cannot prove arbitrary Nix code or package closures secret-free. Review custom inputs/configuration.'}
