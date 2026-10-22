#!/usr/bin/env bash
# Manually update selected flake inputs, build, switch, then optionally commit.
# No background updates, auto-clean, firmware changes, or automatic reboot.
set -Eeuo pipefail
REPO="${NIX_UPDATE_REPO:-$HOME/nixos-config}"
HOST="${NIX_UPDATE_HOST:-ankur-laptop}"
DIAGNOSTICS="${NIX_UPDATE_DIAGNOSTICS:-true}"
SAFE_ALL="${NIX_UPDATE_SAFE_ALL:-true}"
ALLOW_ALL="${NIX_UPDATE_ALL:-false}"
ALLOW_FIMLOOM="${NIX_UPDATE_FIMLOOM:-false}"
ALLOW_PIN="${NIX_UPDATE_NIXPKGS_PIN:-false}"
FLAKE_CHECK="${NIX_UPDATE_FLAKE_CHECK:-false}"
CONFIRM="${NIX_UPDATE_CONFIRM:-true}"
AUTO_COMMIT="${NIX_UPDATE_COMMIT:-true}"

say() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
help_text() {
  cat <<'USAGE'
nix-update-safe status                  Read-only Git and flake-pin status
nix-update-safe input <name>            Update ONE input (FIMLoom and pins guarded)
nix-update-safe safe-all                Update eligible moving inputs, exclude pins/FIMLoom
nix-update-safe all                     Update every input (requires explicit opt-in)
nix-update-safe pin-nixpkgs <40hexsha>  Change explicitly pinned Nixpkgs revision (opt-in)
nix-update-safe help

Every update requires a clean Git checkout, stages changes for Nix flake evaluation,
then runs nh os build -> (optional nix flake check) -> nh os switch -> Git commit.
No-op updates do not build, switch or commit. Errors before activation restore the
previous flake.nix and flake.lock; a failed switch may partially activate services.
USAGE
}

mode="${1:-help}"
if [[ "$mode" == help || "$mode" == --help || "$mode" == -h ]]; then help_text; exit 0; fi
[[ "$EUID" -ne 0 ]] || die 'Do not run as root; nh handles elevation for switching.'
for x in git nix nh jq python3; do command -v "$x" >/dev/null || die "Missing command $x"; done
[[ -f "$REPO/flake.nix" && -f "$REPO/flake.lock" ]] || die "No flake found at $REPO"
[[ "$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)" == "$(cd "$REPO" && pwd -P)" ]] || die 'Repo must be Git root.'
[[ "$HOST" == ankur-laptop ]] || die 'Unexpected host. Verify NIX_UPDATE_HOST.'

case "$mode" in
status)
  [[ "$DIAGNOSTICS" == true ]] || die 'Status diagnostics disabled by module switch.'
  echo "Flake: $REPO   Host: $HOST"
  git -C "$REPO" status --short
  echo 'Top-level locked inputs:'
  jq -r '.nodes as $nodes | .nodes.root.inputs | to_entries[] | .key as $key | .value as $ref | (if ($ref|type)=="string" then $ref else ($ref[0] // "") end) as $node | [$key,($nodes[$node].locked.rev // $nodes[$node].locked.ref // "followed/unknown")] | @tsv' "$REPO/flake.lock"
  echo "FIMLoom changes permitted: $ALLOW_FIMLOOM; Nixpkgs pin changes permitted: $ALLOW_PIN"
  echo "Pin: $(grep -E -m1 'github:NixOS/nixpkgs\?rev=' "$REPO/flake.nix" | sed 's/^[[:space:]]*//' || true)"
  exit 0 ;;
input) [[ $# -eq 2 ]] || die 'Usage: nix-update-safe input <name>' ;;
safe-all|all) [[ $# -eq 1 ]] || die "Unexpected args for $mode" ;;
pin-nixpkgs) [[ $# -eq 2 ]] || die 'Usage: nix-update-safe pin-nixpkgs <40hexsha>' ;;
*) die "Unknown command '$mode'; run nix-update-safe help" ;;
esac

[[ -z "$(git -C "$REPO" status --porcelain --untracked-files=normal)" ]] || die 'Working tree is dirty; commit/stash before updating.'
MUTATED=0
ACTIVATED=0
SWITCH_STARTED=0
finish() {
  rc=$?
  trap - EXIT INT TERM
  if (( rc != 0 && MUTATED == 1 && ACTIVATED == 0 )); then
    echo 'Restoring flake.nix / flake.lock to committed versions.' >&2
    git -C "$REPO" restore --source=HEAD --staged --worktree -- flake.lock flake.nix || true
    if (( SWITCH_STARTED == 1 )); then
      echo 'WARNING: nh os switch failed; runtime services may be partially activated.' >&2
      echo 'Check systemctl --failed and consider rebooting to a known-good generation.' >&2
    fi
  elif (( rc != 0 && ACTIVATED == 1 )); then
    echo 'Activation succeeded; staged Git changes kept because post-switch commit failed.' >&2
  fi
  exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Only known root inputs may be selected; reject nested inputs or arbitrary arguments.
root_has() { jq -e --arg name "$1" '.nodes.root.inputs | has($name)' "$REPO/flake.lock" >/dev/null; }
cd "$REPO"
case "$mode" in
input)
  name="$2"
  [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || die 'Invalid input name.'
  root_has "$name" || die "Input '$name' not present in flake.lock"
  [[ "$name" != nixpkgs ]] || die 'Nixpkgs is commit-pinned. Use pin-nixpkgs with explicit permission.'
  [[ "$name" != smoothcursor ]] || die 'SmoothCursor is fixed to a commit: leave pinned.'
  [[ "$name" != fimloom || "$ALLOW_FIMLOOM" == true ]] || die 'FIMLoom protected by switch.'
  say "Update one input: $name"
  MUTATED=1
  nix flake update "$name" --flake "$REPO"
  ;;
safe-all)
  [[ "$SAFE_ALL" == true ]] || die 'safe-all is disabled by configuration.'
  names=()
  for n in home-manager nixvim nvimEmmet vimReactSnippets; do
    if root_has "$n"; then names+=("$n"); fi
  done
  (( ${#names[@]} > 0 )) || die 'No known safe moving inputs found.'
  say "Update safe moving inputs: ${names[*]} (FIMLoom and pinned inputs excluded)"
  MUTATED=1
  nix flake update "${names[@]}" --flake "$REPO"
  ;;
all)
  [[ "$ALLOW_ALL" == true && "$ALLOW_FIMLOOM" == true ]] || die 'all requires both allInputs and allowFimloom switches. Use safe-all otherwise.'
  say 'Update ALL inputs (may also update FIMLoom; Nixpkgs rev remains pinned)'
  MUTATED=1
  nix flake update --flake "$REPO"
  ;;
pin-nixpkgs)
  [[ "$ALLOW_PIN" == true ]] || die 'Nixpkgs pin changes disabled by module switch.'
  sha="$2"
  [[ "$sha" =~ ^[a-fA-F0-9]{40}$ ]] || die 'Revision must be exactly a 40-character Git SHA.'
  say "Change Nixpkgs pin to $sha (caller must verify release-branch compatibility)"
  MUTATED=1
  python3 - "$REPO/flake.nix" "$sha" <<'PYEDIT'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); rev = sys.argv[2]
s = p.read_text()
pat = r'(nixpkgs\.url\s*=\s*"github:NixOS/nixpkgs\?rev=)([0-9a-fA-F]{40})("\s*;)'
new, count = re.subn(pat, lambda m: m.group(1)+rev+m.group(3), s)
if count != 1: raise SystemExit('Expected one exact pinned Nixpkgs input; refusing unsafe edit.')
p.write_text(new)
PYEDIT
  nix flake update nixpkgs --flake "$REPO"
  ;;
esac

# For a Git flake, newly modified paths must be staged for the build to see them.
git add -- flake.lock flake.nix
git diff --cached --check
if git diff --cached --quiet; then
  MUTATED=0
  echo 'No new lock or flake change; no switch or commit required.'
  exit 0
fi
say 'Review proposed lockfile changes (no activation yet)'
git diff --cached --stat
git diff --cached -- flake.nix
git diff --cached -- flake.lock | head -100 || true

say 'Validate by building (does not activate)'
nh os build "$REPO" -H "$HOST"
if [[ "$FLAKE_CHECK" == true ]]; then
  say 'Extra validation: nix flake check (may take time)'
  nix flake check --no-update-lock-file "$REPO"
fi
if [[ "$CONFIRM" == true ]]; then
  [[ -t 0 ]] || die 'Confirmation requires a terminal. Nothing switched.'
  echo 'Build succeeded. Type SWITCH to activate this update:'
  read -r answer
  [[ "$answer" == SWITCH ]] || die 'Switch not approved. No activation performed.'
fi
say 'Activate verified configuration'
SWITCH_STARTED=1
nh os switch "$REPO" -H "$HOST"
ACTIVATED=1
if [[ "$AUTO_COMMIT" == true ]]; then
  git commit -m "Update NixOS flake inputs ($mode)"
  say 'Activated and committed locally. No Git push performed.'
else
  say 'Activated; auto-commit disabled. Changes remain staged for manual commit.'
fi
