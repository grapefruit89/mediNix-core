#!/usr/bin/env bash
# ---
# id: "verify"
# title: "Volle lokale Pruef-Leiter (CI-paritaetisch)"
# domain: 50
# folder: "scripts"
# status: active
# kind: tooling
# complexity: 2
# last_reviewed: 2026-11-05
# links:
#   adr: ADR-0000
# ---
# scripts/verify.sh — die EINE lokale Leiter, die vor jedem Commit gruen sein muss.
#
# Warum es dieses Skript gibt (L-048, zweimal passiert):
#   2026-11-04 war die CI zweimal rot, obwohl lokal "alles gruen" war. Ursache war
#   beide Male eine unvollstaendige lokale Leiter:
#     1. `nix flake check --no-build` baut die Check-Derivations NICHT. `check-nixfmt`
#        lief nie -> 14 unformatierte Dateien fielen erst in der CI auf.
#     2. `scripts/gen_service_map.py --check` stand gar nicht in der Leiter.
#   Dieses Skript sammelt beides ein und ist die Referenz fuer "gruen".
#
# Fallstrick, der hier festgehalten ist:
#   `nix fmt -- --check` OHNE Dateiliste ist auf Determinate Nix 3.23.2 / Nix 2.35.3
#   wirkungslos: nixfmt bekommt keine Dateien, liest stdin und bricht mit Exit 1 aus
#   dem falschen Grund ab. Deshalb wird die Dateiliste explizit uebergeben — genau
#   wie `checks.nixfmt-check` in flake.nix es tut.
#
# Aufruf:  bash scripts/verify.sh            # volle Leiter, inkl. Builds (~5-10 min)
#          bash scripts/verify.sh --fast     # nur Auswertung, OHNE Builds — NICHT
#                                            # commit-faehig, nur fuer Zwischenstaende
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT" || exit 1

FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

fail=0
pass=0
failed_names=()

run() {
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  \033[32mOK\033[0m    %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  \033[31mROT\033[0m   %s\n' "$name"
    printf '%s\n' "$out" | tail -15 | sed 's/^/        /'
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
}

echo "== Stufe 1: Nix-Formalie ============================================="
# Batches/ sind Symlinks auf Quellen - sonst formatiert nixfmt dieselbe Datei zweimal.
mapfile -t nixfiles < <(find . -name '*.nix' -not -path './.git/*' -not -path './Batches/*' | sort)
printf '  (%d .nix-Dateien)\n' "${#nixfiles[@]}"
run "nixfmt --check" nix fmt -- --check "${nixfiles[@]}"

echo "== Stufe 2: Flake ===================================================="
if [ "$FAST" -eq 1 ]; then
  echo "  WARNUNG: --fast ueberspringt die Builds. Das ist NICHT commit-faehig:"
  echo "           check-nixfmt, statix, deadnix und die VM-Tests laufen dann nicht."
  run "nix flake check --no-build" nix flake check --no-build
else
  run "nix flake check (mit Builds)" nix flake check --print-build-logs
fi

echo "== Stufe 3: Repo-Gates ==============================================="
run "nixmeta_check"            python3 scripts/nixmeta_check.py
run "check_skills"             python3 scripts/check_skills.py
run "check_tasks"              python3 scripts/check_tasks.py
run "check_adrs"               python3 scripts/check_adrs.py
run "medinix-meta check-docs"  python3 scripts/medinix-meta.py check-docs
run "check-nixmap"             python3 scripts/check-nixmap.py
run "check_manifest_edge"      python3 scripts/check_manifest_edge.py
run "check_sources"            python3 scripts/check_sources.py
run "check_corridor"           python3 scripts/check_corridor.py
run "check_nixos_anchors"      python3 scripts/check_nixos_anchors.py
run "check_banned_technologies" python3 scripts/check_banned_technologies.py
run "nixos_idiom_audit --p0"   python3 scripts/nixos_idiom_audit.py --p0-only

echo "== Stufe 4: Generatoren aktuell? ====================================="
run "gen_service_map --check"  python3 scripts/gen_service_map.py --check
run "gen_runbook --check"      python3 scripts/gen_runbook.py --check
run "nixos-resources --check"  python3 scripts/nixos-resources.py --check
run "gen_plan --check"        python3 scripts/gen_plan.py --check
run "gen_todo --check"        python3 scripts/gen_todo.py --check

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mLeiter gruen: %d Pruefungen.\033[0m\n' "$pass"
  [ "$FAST" -eq 1 ] && echo "ABER: --fast war aktiv — vor dem Commit ohne --fast wiederholen."
  exit 0
fi
printf '\033[31mLeiter ROT: %d von %d Pruefungen fehlgeschlagen.\033[0m\n' "$fail" "$((pass + fail))"
printf '  Gescheitert: %s\n' "${failed_names[*]}"
exit 1
