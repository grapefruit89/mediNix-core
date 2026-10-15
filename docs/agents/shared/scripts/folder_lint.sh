#!/usr/bin/env bash
# folder_lint.sh — Ordner-Spam-Lint
#
# REGEL (docs/CONVENTIONS.md): Ein Ordner existiert erst ab >= 3 Dateien.
# AUSNAHMEN (dürfen < 3 Dateien, sind strukturell vorgeschrieben):
#   - NN- Domain-Ordner            (Decimal-Framework / ADR-0000, Auto-Import)
#   - Nix-Paketordner              (enthalten default.nix)
#   - Skill-Ordner                 (enthalten SKILL.md)
#   - tests | scripts | references | templates
#   - alles unter .agents/ | .github/ | .git/
#
# Nutzung:  bash docs/agents/shared/scripts/folder_lint.sh [repo-root]
# Exit: 0 = sauber, 1 = Verstoß gefunden (für CI).
set -u

base="$(realpath "${1:-.}")"
allow='^(tests|scripts|references|templates|\.agents|\.git|__pycache__)$'
hits=0

while IFS= read -r d; do
  [ "$d" = "$base" ] && continue
  bn="$(basename "$d")"

  [[ "$bn" =~ ^[0-9]{2}- ]] && continue
  [[ "$bn" =~ $allow ]] && continue
  [[ "$d" == */.agents/* || "$d" == */.github/* || "$d" == */.git/* ]] && continue
  [ -f "$d/default.nix" ] && continue
  [ -f "$d/SKILL.md" ] && continue

  n=$(find "$d" -maxdepth 1 -type f ! -name '.gitkeep' 2>/dev/null | wc -l)
  sub=$(find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [ "$n" -lt 3 ] && [ "$sub" -eq 0 ]; then
    rel="${d#"$base"/}"
    echo "::warning file=$rel::Ordner mit $n Datei(en) — Regel verlangt >= 3 (oder eine Ausnahme)."
    echo "  ⚠ $n Datei(en): $rel"
    hits=$((hits + 1))
  fi
done < <(find "$base" -type d ! -path '*/.git/*' ! -path '*__pycache__*' 2>/dev/null)

echo "folder-lint: $hits verdächtige(r) Ordner"
[ "$hits" -eq 0 ]
