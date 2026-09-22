#!/usr/bin/env bash
# radar-task.sh — the deterministic mechanics of parallel mode.
#
#   radar-task.sh new <task-id> [--base <ref>] [--branch <name>]
#   radar-task.sh list
#   radar-task.sh teardown <task-id> [--check]
#
# radar calls this; a human may too. It cuts the worktree, renders the per-task
# coder config, and refuses to destroy work that has not landed. Everything it
# does is exact and repeatable — which is why it is a script and not a prompt.
#
# CONTRACT
#   - Run from the repository root (radar's working directory).
#   - <task-id> is [A-Za-z0-9._-]+ and becomes a directory and a config name.
#   - `new` is idempotent for an existing task: it re-renders the config and
#     leaves the worktree alone, so a template fix reaches a live task.
#   - `teardown` without --check exits 3 and changes NOTHING when the branch
#     holds commits that are on no other ref, or the tree is dirty.
#     `--check` reports the same verdict on stdout and always exits 0.
#
# The task-id is NOT sanitised into a branch name: pass --branch when the
# tracker's convention differs from `radar/<task-id>`.
set -euo pipefail

BUNDLE_ROOT=""   # resolved below
OMNI=".omnigent"
WT_ROOT="$OMNI/worktrees"
TASK_ROOT="$OMNI/tasks"

die() { printf 'radar-task: %s\n' "$*" >&2; exit 2; }

resolve_bundle() {
  local src="${BASH_SOURCE[0]}" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  BUNDLE_ROOT="$(cd -P "$(dirname "$src")/.." && pwd)/agents/radar"
  if [ ! -f "$BUNDLE_ROOT/templates/coder.yaml" ]; then
    die "no coder template at $BUNDLE_ROOT/templates/coder.yaml"
  fi
}

require_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || die "not a git repository: $PWD"
  local top; top="$(git rev-parse --show-toplevel)"
  if [ "$top" != "$PWD" ]; then
    die "run from the repository root ($top), not $PWD"
  fi
}

valid_id() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
    .|..) return 1 ;;
    *) return 0 ;;
  esac
}

ensure_gitignore() {
  # Keeps the running tasks out of `git status`, which is what Omnigent's
  # changed-files view reads. Without it a nested worktree shows up as one
  # useless untracked directory row per live task. Scoped to .omnigent/ so
  # the project's own root .gitignore is never touched.
  mkdir -p "$OMNI"
  local f="$OMNI/.gitignore" entry
  [ -f "$f" ] || : > "$f"
  for entry in "runs/" "worktrees/" "tasks/"; do
    if ! grep -qxF "$entry" "$f"; then printf '%s\n' "$entry" >> "$f"; fi
  done
}

render_config() {
  # $1 task-id, $2 worktree (relative, no trailing slash), $3 branch
  local id="$1" wt="$2" branch="$3" dest="$TASK_ROOT/$1"
  rm -rf "$dest"
  mkdir -p "$dest"
  # sed with | as the delimiter: none of the three values may contain one, and
  # valid_id plus git's own ref rules already guarantee that.
  sed -e "s|{{TASK_ID}}|$id|g" -e "s|{{WORKTREE}}|$wt|g" -e "s|{{BRANCH}}|$branch|g" \
      "$BUNDLE_ROOT/templates/coder.yaml" > "$dest/config.yaml"
  # A config_path launch carries the bundle's skills with it, so the coder's
  # own skills have to travel beside the rendered config — the parent bundle's
  # do not reach a child spawned this way.
  if [ -d "$BUNDLE_ROOT/agents/coder/skills" ]; then
    cp -R "$BUNDLE_ROOT/agents/coder/skills" "$dest/skills"
  fi
}

cmd_new() {
  local id="" base="" branch=""
  id="${1:-}"; shift || true
  valid_id "$id" || die "task id must be [A-Za-z0-9._-]+, got '${id}'"
  while [ $# -gt 0 ]; do
    case "$1" in
      --base)   base="${2:-}"; [ -n "$base" ] || die "--base needs a value"; shift 2 ;;
      --branch) branch="${2:-}"; [ -n "$branch" ] || die "--branch needs a value"; shift 2 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$branch" ] || branch="radar/$id"
  if [ -z "$base" ]; then
    base="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"
  fi
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "invalid branch name: $branch"

  ensure_gitignore
  local wt="$WT_ROOT/$id"
  if [ -d "$wt" ]; then
    render_config "$id" "$wt" "$branch"
    printf 'task=%s worktree=%s branch=%s config=%s status=reused\n' \
      "$id" "$wt" "$(git -C "$wt" symbolic-ref --quiet --short HEAD || echo DETACHED)" "$TASK_ROOT/$id"
    return 0
  fi
  mkdir -p "$WT_ROOT"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add --quiet "$wt" "$branch"
  else
    git worktree add --quiet -b "$branch" "$wt" "$base"
  fi
  render_config "$id" "$wt" "$branch"
  printf 'task=%s worktree=%s branch=%s base=%s config=%s status=created\n' \
    "$id" "$wt" "$branch" "$base" "$TASK_ROOT/$id"
}

cmd_list() {
  # What is TRUE on disk, not what was recorded. git is the registry.
  if [ ! -d "$WT_ROOT" ]; then echo "no tasks"; return 0; fi
  local wt id branch dirty ahead found=0
  while IFS= read -r wt; do
    case "$wt" in "$PWD/$WT_ROOT"/*) ;; *) continue ;; esac
    id="${wt##*/}"
    branch="$(git -C "$wt" symbolic-ref --quiet --short HEAD || echo DETACHED)"
    dirty="$(git -C "$wt" status --porcelain --untracked-files=all | wc -l | tr -d ' ')"
    ahead="$(unlanded_count "$wt")"
    found=1
    printf 'task=%s branch=%s dirty=%s unlanded_commits=%s config=%s\n' \
      "$id" "$branch" "$dirty" "$ahead" "$TASK_ROOT/$id"
  done < <(git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}')
  if [ "$found" = "0" ]; then echo "no tasks"; fi
}

# The landed-work test. It lives here and nowhere else — a second opinion about
# what "safe to delete" means is how work gets destroyed.
#
# Landed means: every commit on this worktree's HEAD is reachable from somewhere
# that survives the worktree. A remote-tracking ref is that somewhere, because
# `deliver` pushes. A repository with no remote at all falls back to its default
# branch, and when neither can be resolved the verdict is `unverifiable` — which
# refuses, because "I could not check" must never read as "safe".
#
# Deliberately NOT compared against other local branches: a sibling task's
# branch containing the same commit would mean nothing about this one.
landing_refs() {
  local wt="$1"
  if [ -n "$(git -C "$wt" for-each-ref --format='%(refname)' refs/remotes 2>/dev/null)" ]; then
    echo "--remotes"; return 0
  fi
  local d
  for d in "$(git -C "$wt" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)" main master; do
    if [ -n "$d" ] && git -C "$wt" show-ref --verify --quiet "refs/heads/$d"; then
      printf 'refs/heads/%s\n' "$d"; return 0
    fi
  done
  return 1
}

unlanded_count() {
  local wt="$1" refs
  if ! refs="$(landing_refs "$wt")"; then echo "?"; return 0; fi
  # shellcheck disable=SC2086 — $refs is one token we produced ourselves.
  git -C "$wt" log --oneline HEAD --not $refs 2>/dev/null | wc -l | tr -d ' '
}

verdict_for() {
  local wt="$1" branch dirty unlanded
  branch="$(git -C "$wt" symbolic-ref --quiet --short HEAD || echo DETACHED)"
  dirty="$(git -C "$wt" status --porcelain --untracked-files=all | wc -l | tr -d ' ')"
  if [ "$dirty" != "0" ]; then echo "dirty:$dirty"; return 0; fi
  if [ "$branch" = "DETACHED" ]; then echo "detached"; return 0; fi
  unlanded="$(unlanded_count "$wt")"
  if [ "$unlanded" = "?" ]; then echo "unverifiable"; return 0; fi
  if [ "$unlanded" != "0" ]; then echo "unlanded:$unlanded"; return 0; fi
  echo "landed"
}

cmd_teardown() {
  local id="${1:-}" check=0
  valid_id "$id" || die "task id must be [A-Za-z0-9._-]+, got '${id}'"
  shift || true
  if [ "${1:-}" = "--check" ]; then check=1; fi
  local wt="$WT_ROOT/$id"
  [ -d "$wt" ] || die "no worktree for task '$id' at $wt"
  local verdict; verdict="$(verdict_for "$wt")"
  if [ "$check" = "1" ]; then
    printf 'task=%s verdict=%s\n' "$id" "$verdict"
    return 0
  fi
  if [ "$verdict" != "landed" ]; then
    {
      printf 'REFUSED: task %s still holds work (%s)\n' "$id" "$verdict"
      printf '  worktree: %s\n' "$wt"
      printf '  Land it (deliver) or discard it deliberately, then retry.\n'
    } >&2
    exit 3
  fi
  git worktree remove "$wt"
  rm -rf "${TASK_ROOT:?}/$id"
  printf 'task=%s status=removed\n' "$id"
}

resolve_bundle
require_repo
case "${1:-}" in
  new)      shift; cmd_new "$@" ;;
  list)     shift || true; cmd_list ;;
  teardown) shift; cmd_teardown "$@" ;;
  ''|-h|--help)
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command: $1" ;;
esac
