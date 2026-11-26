#!/usr/bin/env bash
# vpn-killswitch-test.sh -- prueft den SABnzbd-VPN-Kill-Switch REAL. Als root.
# Voraussetzung: killswitch aktiv + VPN-Interface existiert.
# Task R73: Echter Egress-Leak-Test zur Laufzeit.
set -uo pipefail

IFACE="${1:-wg0}"
SAB="sabnzbd"

sab() { sudo -u "$SAB" "$@"; }

echo "== 1. SABnzbd-UID (muss 5410 sein) =="
id "$SAB"

echo "== 2. nftables Kill-Switch (Tabelle medinix_vpn_filter) =="
nft list table inet medinix_vpn_filter 2>/dev/null || echo "  FEHLT!"

echo "== 3. Policy-Routing (Tabelle 51820 / UID 5410) =="
ip rule show | grep 5410 || echo "  keine rule für UID 5410"
ip route show table 51820 || echo "  Routing-Tabelle 51820 ist leer"

echo "== 4. VPN OBEN -> Traffic (sollte VPN-IP zeigen) =="
sab curl -s --max-time 8 https://ipv4.icanhazip.com && echo || echo "  kein Traffic (VPN unten?)"

echo "== 5. DNS-Aufloesung SABnzbd =="
sab getent hosts example.com || echo "  keine DNS-Aufloesung"

echo
echo "== 6. VPN RUNTER: 'sudo ip link set $IFACE down' -- dann Enter druecken =="
read -r _

echo "== 7. VPN UNTEN -> NICHTS darf raus =="
if sab curl -s --max-time 8 https://ipv4.icanhazip.com; then
  echo "  !!! LEAK: Traffic fliesst trotz downed VPN !!!"
else
  echo "  OK: fail-closed, kein Byte raus"
fi

echo "== 8. Drop-Zaehler =="
nft list table inet medinix_vpn_filter 2>/dev/null | grep -A1 drop || echo "  keine Drop-Zaehler gefunden"

echo "== 9. DNS unten -> darf nicht aufloesen =="
if sab getent hosts example.com; then
  echo "  !!! DNS-LEAK: DNS loest bei downed VPN auf !!!"
else
  echo "  OK: DNS auch blockiert"
fi
