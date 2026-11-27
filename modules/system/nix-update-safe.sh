#!/usr/bin/env bash
# Prepare and validate flake updates on demand.
set -Eeuo pipefail
REPO="${NIX_UPDATE_REPO:-$HOME/nixos-config}"
HOST="${NIX_UPDATE_HOST:-nixos}"
DIAGNOSTICS="${NIX_UPDATE_DIAGNOSTICS:-true}"
SAFE_ALL="${NIX_UPDATE_SAFE_ALL:-true}"
ALLOW_ALL="${NIX_UPDATE_ALL:-false}"
ALLOW_FIMLOOM="${NIX_UPDATE_FIMLOOM:-false}"
ALLOW_PIN="${NIX_UPDATE_NIXPKGS_PIN:-false}"
FLAKE_CHECK="${NIX_UPDATE_FLAKE_CHECK:-false}"
CONFIRM="${NIX_UPDATE_CONFIRM:-true}"
AUTO_COMMIT="${NIX_UPDATE_COMMIT:-true}"
DEFAULT_ISO_PROFILE=my_nix_garuda_iso
SYSTEM_INPUTS=(nixpkgs home-manager nixvim)
EDITOR_INPUTS=(nvimEmmet vimReactSnippets)

say() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
help_text() {
  cat <<'USAGE'
nix-update-safe status                           Show Git and flake-pin status
nix-update-safe prepare system [ISO_PROFILE]     Update Nixpkgs, Home Manager and Nixvim
nix-update-safe prepare editor                   Update Emmet and React snippets
nix-update-safe prepare input NAME               Update a single moving input
nix-update-safe prepare input fimloom --allow-fimloom
nix-update-safe validate [ISO_PROFILE]           Build the currently locked candidate
nix-update-safe help

Run prepare from a clean update worktree. It leaves the proposed lockfile diff
unstaged and stops after building. System updates also build Garuda Home Manager
and the selected ISO (default my_nix_garuda_iso). For validate, supply a profile
name to include those builds. Validate uses the current flake.lock as-is.

The legacy input NAME, safe-all, all and pin-nixpkgs SHA commands use the configured
checkout and offer to switch after building. The all and pin-nixpkgs commands
require explicit module settings. Use prepare for a separate activation decision.
USAGE
}

root_has() { jq -e --arg name "$1" '.nodes[.root].inputs | has($name)' flake.lock >/dev/null; }
require_input() {
  [[ "$1" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || die 'Invalid input name.'
  root_has "$1" || die "Input '$1' not present in flake.lock"
}

validate_candidate() {
  local profile="$1"
  say 'Run repository checks and build declared flake checks'
  bash scripts/check.sh
  nix flake check --no-update-lock-file
  say "Build NixOS host $HOST"
  nh os build . -H "$HOST" --no-update-lock-file
  if [[ -n "$profile" ]]; then
    say 'Build standalone Garuda Home Manager'
    nix build --no-link --no-update-lock-file '.#homeConfigurations."ankur@garuda".activationPackage'
    say "Validate ISO profile $profile"
    bash scripts/build-iso.sh --profile "$profile" --validate-only
  fi
}

mode="${1:-help}"
if [[ "$mode" == help || "$mode" == --help || "$mode" == -h ]]; then help_text; exit 0; fi
[[ "$EUID" -ne 0 ]] || die 'Do not run as root; nh handles elevation for switching.'
for x in git nix nh jq python3; do command -v "$x" >/dev/null || die "Missing command $x"; done
if [[ "$mode" == prepare || "$mode" == validate ]]; then
  REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die 'Run this from your NixOS config worktree.'
fi
[[ -f "$REPO/flake.nix" && -f "$REPO/flake.lock" ]] || die "No flake found at $REPO"
[[ "$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)" == "$(cd "$REPO" && pwd -P)" ]] || die 'Repo must be Git root.'
[[ "$HOST" == nixos ]] || die 'Unexpected host. Verify NIX_UPDATE_HOST.'

case "$mode" in
status)
  [[ "$DIAGNOSTICS" == true ]] || die 'Status diagnostics disabled by module switch.'
  echo "Flake: $REPO   Host: $HOST"
  git -C "$REPO" status --short
  echo 'Top-level locked inputs:'
  jq -r '.nodes as $nodes | .nodes.root.inputs | to_entries[] | .key as $key | .value as $ref | (if ($ref|type)=="string" then $ref else ($ref[0] // "") end) as $node | [$key,($nodes[$node].locked.rev // $nodes[$node].locked.ref // "followed/unknown")] | @tsv' "$REPO/flake.lock"
  echo "FIMLoom changes permitted: $ALLOW_FIMLOOM; Nixpkgs pin changes permitted: $ALLOW_PIN"
  jq -r '"Nixpkgs source: " + (.nodes[.nodes[.root].inputs.nixpkgs].original | .ref // .rev // "unknown")' "$REPO/flake.lock"
  exit 0 ;;
prepare|validate) ;;
input) [[ $# -eq 2 ]] || die 'Usage: nix-update-safe input <name>' ;;
safe-all|all) [[ $# -eq 1 ]] || die "Unexpected args for $mode" ;;
pin-nixpkgs) [[ $# -eq 2 ]] || die 'Usage: nix-update-safe pin-nixpkgs <40hexsha>' ;;
*) die "Unknown command '$mode'; run nix-update-safe help" ;;
esac

cd "$REPO"
command -v flock >/dev/null || die 'Missing command flock'
exec {update_lock}>"$(git rev-parse --absolute-git-dir)/nix-update-safe.lock"
flock -n "$update_lock" || die 'Another update or validation is already running in this worktree.'

if [[ "$mode" != validate ]]; then
  worktree_status="$(git status --porcelain --untracked-files=normal)"
  [[ -z "$worktree_status" ]] || die 'Working tree has changes. Use a clean update worktree or validate the current candidate.'
fi

if [[ "$mode" == prepare || "$mode" == validate ]]; then
  [[ -f scripts/check.sh ]] || die 'Missing scripts/check.sh in this worktree.'
  profile=
  if [[ "$mode" == validate ]]; then
    [[ $# -le 2 ]] || die 'Usage: nix-update-safe validate [ISO_PROFILE]'
    profile="${2:-}"
  else
    case "${2:-}" in
      system)
        [[ $# -le 3 ]] || die 'Usage: nix-update-safe prepare system [ISO_PROFILE]'
        names=("${SYSTEM_INPUTS[@]}")
        profile="${3:-$DEFAULT_ISO_PROFILE}"
        ;;
      editor)
        [[ $# -eq 2 ]] || die 'Usage: nix-update-safe prepare editor'
        names=("${EDITOR_INPUTS[@]}")
        ;;
      input)
        [[ $# -eq 3 || ( $# -eq 4 && "$3" == fimloom && "$4" == --allow-fimloom ) ]] \
          || die 'Usage: nix-update-safe prepare input NAME [--allow-fimloom for fimloom]'
        name="$3"
        case "$name" in
          smoothcursor|neominimap) die "Change the fixed $name source in flake.nix and refresh its lock entry explicitly." ;;
          fimloom)
            [[ "$ALLOW_FIMLOOM" == true || "${4:-}" == --allow-fimloom ]] \
              || die 'Pass --allow-fimloom to prepare a FIMLoom update explicitly.'
            ;;
          nixpkgs|home-manager|nixvim) profile="$DEFAULT_ISO_PROFILE" ;;
        esac
        names=("$name")
        ;;
      *) die 'Usage: nix-update-safe prepare {system|editor|input}; see help' ;;
    esac
  fi
  [[ -z "$profile" || ( "$profile" =~ ^[a-z]([a-z0-9_-]{0,61}[a-z0-9])?$ && -f "iso-configs/$profile.nix" ) ]] \
    || die "Unknown ISO profile '$profile'. Run bash scripts/build-iso.sh --list."
  if [[ "$mode" == prepare ]]; then
    for name in "${names[@]}"; do require_input "$name"; done
    say "Update inputs in $REPO: ${names[*]}"
    nix flake update "${names[@]}"
    say 'Review the lockfile candidate'
    git --no-pager diff -- flake.lock
    if git diff --quiet -- flake.lock; then
      echo 'The lockfile stayed the same. Validating the current revisions.'
    fi
  fi
  validate_candidate "$profile"
  say 'Build checks passed. Review this worktree before activating or booting the candidate.'
  exit 0
fi

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

case "$mode" in
input)
  name="$2"
  require_input "$name"
  [[ "$name" != nixpkgs ]] || die 'Use prepare system from an update worktree to build a Nixpkgs update.'
  [[ "$name" != smoothcursor ]] || die 'SmoothCursor is fixed to a commit: leave pinned.'
  [[ "$name" != fimloom || "$ALLOW_FIMLOOM" == true ]] || die 'FIMLoom protected by switch.'
  say "Update one input: $name"
  MUTATED=1
  nix flake update "$name" --flake "$REPO"
  ;;
safe-all)
  [[ "$SAFE_ALL" == true ]] || die 'safe-all is disabled by configuration.'
  names=()
  for n in home-manager nixvim "${EDITOR_INPUTS[@]}"; do
    if root_has "$n"; then names+=("$n"); fi
  done
  (( ${#names[@]} > 0 )) || die 'No known safe moving inputs found.'
  say "Update safe moving inputs: ${names[*]} (FIMLoom and pinned inputs excluded)"
  MUTATED=1
  nix flake update "${names[@]}" --flake "$REPO"
  ;;
all)
  [[ "$ALLOW_ALL" == true && "$ALLOW_FIMLOOM" == true ]] || die 'all requires both allInputs and allowFimloom switches. Use safe-all otherwise.'
  say 'Update ALL inputs (including FIMLoom and the Nixpkgs source)'
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
pat = r'(nixpkgs\.url\s*=\s*"github:NixOS/nixpkgs)(?:\?rev=[0-9a-fA-F]{40}|/nixos-[0-9]{2}\.[0-9]{2})("\s*;)'
new, count = re.subn(pat, lambda m: m.group(1) + '?rev=' + rev + m.group(2), s)
if count != 1: raise SystemExit('Expected one matching Nixpkgs input; refusing unsafe edit.')
p.write_text(new)
PYEDIT
  nix flake update nixpkgs --flake "$REPO"
  ;;
esac

# Stage the exact update for review/commit; new files need staging for Git flakes.
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
