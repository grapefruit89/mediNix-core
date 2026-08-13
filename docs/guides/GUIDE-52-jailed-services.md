---
id: "GUIDE-52-jailed-services"
title: "GUIDE 5200 jailed services"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - sandbox
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ⛓️ Jailed Services: Sandboxing in mynixos

Ein Aviation-Grade System geht davon aus, dass jeder Dienst potenziell kompromittiert werden kann. Wir nutzen Sandboxing, um den Schaden zu begrenzen.

## 🚀 Das Prinzip der geringsten Rechte
Jeder Dienst (Dendrit), der nicht zwingend vollen Systemzugriff benötigt, wird in einem **Jail** ausgeführt.

## 🛠️ Technik: `jail.nix` & `bubblewrap`
Wir nutzen die deklarative Kraft von Nix, um Isolations-Container zu bauen:
- **Mount-Isolation:** Nur benötigte Pfade werden in den Container gemountet.
- **Network-Isolation:** Dienste ohne Internetbedarf werden physisch vom Netzwerk getrennt.
- **Identity-Isolation:** Der Dienst sieht niemals den `age-key.txt` des Hosts.

## 🧩 Anwendung in mynixos
Wir integrieren `jailed-agents.lib` als Input in unsere `flake.nix`, um Funktionen wie `makeJailedAgent` für unsere eigenen Dienste (z.B. Medien-Parser) zu nutzen.
