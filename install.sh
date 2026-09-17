#!/usr/bin/env bash
# radar installer — links bin/radar into a directory on your PATH.
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
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unbekanntes Argument: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK="$TARGET_DIR/radar"

if [ "$MODE" = uninstall ]; then
  if [ -L "$LINK" ]; then rm "$LINK"; echo "entfernt: $LINK"
  else echo "nichts zu entfernen: $LINK ist kein Symlink"; fi
  exit 0
fi

ok=0; warn=0
say()  { printf '  %-14s %s\n' "$1" "$2"; }
good() { say "✓ $1" "$2"; ok=$((ok+1)); }
bad()  { say "✗ $1" "$2"; warn=$((warn+1)); }

echo "Voraussetzungen"

command -v git >/dev/null 2>&1 \
  && good git "$(git --version | head -1)" \
  || bad git "fehlt — radar arbeitet ausschließlich in git-Repos"

if command -v omnigent >/dev/null 2>&1; then
  good omnigent "$(omnigent --version 2>/dev/null | head -1)"
  # Ausgabe erst einsammeln, dann prüfen. Ein `| grep -q` würde die Pipe früh
  # schliessen, omnigent bekäme SIGPIPE, und `pipefail` machte daraus einen
  # Fehlschlag — die Prüfung meldete "kein Provider", obwohl einer da ist.
  cfg="$(omnigent config list 2>/dev/null || true)"
  claude_block="$(printf '%s\n' "$cfg" | awk '/^  Claude$/{f=1;next} /^  [A-Z]/{f=0} f')"
  if printf '%s' "$claude_block" | grep -q '[^[:space:]]' \
     && ! printf '%s' "$claude_block" | grep -q 'none configured'; then
    good provider "Claude-Credentials konfiguriert"
  else
    bad provider "kein Claude-Provider — 'omnigent setup' ausführen"
  fi
else
  bad omnigent "nicht auf dem PATH — siehe https://omnigent.ai/"
fi

# Tracker-CLIs sind pro Projekt relevant, nicht für die Installation.
# Der Exit-Code von `auth status` taugt NICHT als Signal: er ist 1, sobald
# irgendein konfigurierter Host scheitert — auch wenn der Host, den dieses
# Projekt braucht, einwandfrei angemeldet ist. Also die Ausgabe lesen.
for cli in gh glab; do
  if command -v $cli >/dev/null 2>&1; then
    st="$($cli auth status 2>&1 || true)"
    hosts="$(printf '%s\n' "$st" | grep -c 'Logged in' || true)"
    if [ "${hosts:-0}" -gt 0 ]; then
      good "$cli" "$hosts Host(s) angemeldet"
    else
      say "· $cli" "installiert, nirgends angemeldet — nötig für tickets/deliver"
    fi
  else
    say "· $cli" "nicht installiert — nötig nur für Projekte auf dieser Plattform"
  fi
done

echo
echo "Installation"
mkdir -p "$TARGET_DIR"
if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
  echo "  ✗ $LINK existiert und ist kein Symlink — bitte selbst prüfen." >&2
  exit 1
fi
ln -sfn "$ROOT/bin/radar" "$LINK"
good radar "$LINK → $ROOT/bin/radar"

case ":${PATH}:" in
  *":${TARGET_DIR}:"*) good PATH "$TARGET_DIR liegt auf dem PATH" ;;
  *) bad PATH "$TARGET_DIR liegt NICHT auf dem PATH — ergänze:
                 export PATH=\"$TARGET_DIR:\$PATH\"" ;;
esac

echo
if [ "$warn" -eq 0 ]; then
  echo "Fertig. In einem Projektverzeichnis:  radar"
else
  echo "Installiert, aber $warn Punkt(e) offen — radar startet erst, wenn die behoben sind."
fi
