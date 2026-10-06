#!/usr/bin/env bash
# sync-pstack — vendor open-pstack's skill tree into the poteto bundle.
#
#   scripts/sync-pstack.sh            sync to open-pstack's current main
#   scripts/sync-pstack.sh <ref>      sync to a tag, branch or commit sha
#
# The upstream skills are copied byte for byte. Everything poteto adds lives in
# skills it owns (OWN_SKILLS below) and survives a sync untouched. Review the
# resulting diff like any other change before committing it.
set -euo pipefail

REPO_URL="https://github.com/ericlitman/open-pstack"
REF="${1:-main}"

# Skills poteto authors itself. A sync never deletes or overwrites them.
OWN_SKILLS=(omnigent-platform)

# Upstream skills deliberately left out. Each one has its reason in
# agents/poteto/UPSTREAM.md.
EXCLUDED_SKILLS=(setup-pstack)

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT/agents/poteto"
SKILLS="$BUNDLE/skills"
UPSTREAM_DOC="$BUNDLE/UPSTREAM.md"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git -C "$work" init -q
git -C "$work" remote add origin "$REPO_URL"
git -C "$work" fetch -q --depth 1 origin "$REF"
git -C "$work" checkout -q FETCH_HEAD
sha="$(git -C "$work" rev-parse HEAD)"
version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$work/plugins/pstack/.claude-plugin/plugin.json" | head -1)"
src="$work/plugins/pstack/skills"

is_in() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

mkdir -p "$SKILLS"
for dir in "$SKILLS"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  is_in "$name" "${OWN_SKILLS[@]}" || rm -rf "$dir"
done

copied=0
for dir in "$src"/*/; do
  name="$(basename "$dir")"
  is_in "$name" "${EXCLUDED_SKILLS[@]}" && continue
  if is_in "$name" "${OWN_SKILLS[@]}"; then
    echo "sync-pstack: upstream now ships a skill named '$name', which poteto owns — resolve by hand." >&2
    exit 1
  fi
  cp -R "$dir" "$SKILLS/$name"
  copied=$((copied + 1))
done

mkdir -p "$BUNDLE/licenses"
for f in LICENSE LICENSE-cursor-team-kit LICENSE-superpowers NOTICE.md; do
  cp "$work/$f" "$BUNDLE/licenses/$f"
done

pin="open-pstack ${version} at \`${sha}\` (${REPO_URL}/commit/${sha})"
tmp="$(mktemp)"
awk -v pin="$pin" '
  /<!-- pin:begin -->/ { print; print pin; skip=1; next }
  /<!-- pin:end -->/   { skip=0 }
  !skip
' "$UPSTREAM_DOC" > "$tmp"
mv "$tmp" "$UPSTREAM_DOC"

echo "synced $copied skills from open-pstack ${version} (${sha})"
echo "excluded: ${EXCLUDED_SKILLS[*]}"
echo "kept:     ${OWN_SKILLS[*]}"
