#!/usr/bin/env bash
# radar installer — links bin/radar and bin/radar-task.sh into a directory on
# your PATH.
#
# Both, not just the launcher: radar runs with YOUR project as its working
# directory, so a bundle-relative `bin/radar-task.sh` would not resolve there.
# Parallel mode calls it by bare name, which means it has to be on PATH.
#
#   ./install.sh                 install (default target: ~/.local/bin)
#   ./install.sh --dir ~/bin     install elsewhere
#   ./install.sh --uninstall     remove the link
#
# It deliberately does NOT edit your shell config. A symlink in a PATH
# directory works in every shell, is one line to undo, and cannot break a
# login shell the way a bad rc edit can.
set -euo pipefail

TARGET_DIR="${HOME}/.local/bin"
MODE=install
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --uninstall) MODE=uninstall; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK="$TARGET_DIR/radar"
TASK_LINK="$TARGET_DIR/radar-task.sh"

if [ "$MODE" = uninstall ]; then
  for l in "$LINK" "$TASK_LINK"; do
    if [ -L "$l" ]; then rm "$l"; echo "removed: $l"
    else echo "nothing to remove: $l is not a symlink"; fi
  done
  exit 0
fi

ok=0; warn=0
say()  { printf '  %-14s %s\n' "$1" "$2"; }
good() { say "✓ $1" "$2"; ok=$((ok+1)); }
bad()  { say "✗ $1" "$2"; warn=$((warn+1)); }

echo "Prerequisites"

command -v git >/dev/null 2>&1 \
  && good git "$(git --version | head -1)" \
  || bad git "missing — radar works only inside git repositories"

if command -v omnigent >/dev/null 2>&1; then
  good omnigent "$(omnigent --version 2>/dev/null | head -1)"
  # Collect the output first, then inspect it. A `| grep -q` closes the pipe
  # early, omnigent takes SIGPIPE, and `pipefail` turns that into a failure —
  # the check then reports "no provider" while one is configured.
  cfg="$(omnigent config list 2>/dev/null || true)"
  claude_block="$(printf '%s\n' "$cfg" | awk '/^  Claude$/{f=1;next} /^  [A-Z]/{f=0} f')"
  if printf '%s' "$claude_block" | grep -q '[^[:space:]]' \
     && ! printf '%s' "$claude_block" | grep -q 'none configured'; then
    good provider "Claude credentials configured"
  else
    bad provider "no Claude provider — run 'omnigent setup'"
  fi
else
  bad omnigent "not on PATH — see https://omnigent.ai/"
fi

# Tracker CLIs matter per project, not for the installation itself.
# The exit code of `auth status` is NOT a usable signal: it is 1 as soon as any
# configured host fails, even when the host this project needs is signed in
# perfectly well. So read the output instead.
for cli in gh glab; do
  if command -v $cli >/dev/null 2>&1; then
    st="$($cli auth status 2>&1 || true)"
    hosts="$(printf '%s\n' "$st" | grep -c 'Logged in' || true)"
    if [ "${hosts:-0}" -gt 0 ]; then
      good "$cli" "signed in to $hosts host(s)"
    else
      say "· $cli" "installed, not signed in anywhere — needed for tickets/deliver"
    fi
  else
    say "· $cli" "not installed — needed only for projects on that platform"
  fi
done

echo
echo "Installation"
mkdir -p "$TARGET_DIR"
for l in "$LINK" "$TASK_LINK"; do
  if [ -e "$l" ] && [ ! -L "$l" ]; then
    echo "  ✗ $l exists and is not a symlink — please check it yourself." >&2
    exit 1
  fi
done
ln -sfn "$ROOT/bin/radar" "$LINK"
good radar "$LINK → $ROOT/bin/radar"
ln -sfn "$ROOT/bin/radar-task.sh" "$TASK_LINK"
good radar-task "$TASK_LINK → $ROOT/bin/radar-task.sh"

case ":${PATH}:" in
  *":${TARGET_DIR}:"*) good PATH "$TARGET_DIR is on your PATH" ;;
  *) bad PATH "$TARGET_DIR is NOT on your PATH — add:
                 export PATH=\"$TARGET_DIR:\$PATH\"" ;;
esac

echo
if [ "$warn" -eq 0 ]; then
  echo "Done. In any project directory:  radar"
else
  echo "Installed, but $warn item(s) outstanding — radar will not start until they are fixed."
fi
