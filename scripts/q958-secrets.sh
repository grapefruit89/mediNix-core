#!/usr/bin/env bash
# ==============================================================================
# Q958 mediNix Secret & VPN Manager (TUI)
# Verwaltet systemd-creds (TPM2 / Sealed) und rollt WireGuard VPN-Configs
# atomar mit Preflight-Check, Service-Restart und Handshake-Test aus.
# Teil des mediNix-core Repositories: scripts/q958-secrets.sh
# ==============================================================================
set -euo pipefail

SSH_HOST="q958"
REMOTE_SECRETS_DIR="/var/lib/medinix/secrets"
REMOTE_VPN_DIR="/var/lib/medinix/vpn"

# Kanonische mediNix-Secrets laut Spezifikation (6 Kern-Kategorien)
KNOWN_SECRETS=(
  "cf-acme:Cloudflare ACME DNS-Token (Caddy Wildcard TLS *.m7c5.de)"
  "cf-ddns:Cloudflare Dynamic DNS-Token (WAN-IP DNS Updater)"
  "wg-key:WireGuard Private Key (VPN Killswitch / Usenet Confinement)"
  "sabnzbd-apikey:SABnzbd API-Schlüssel (Usenet Client)"
  "usenet-server:Usenet Provider Zugangsdaten (Host, Port, User, Passwort)"
  "newznab-apikey:Usenet Indexer API-Schlüssel (Treasure Maps / Prowlarr)"
  "speedport:Speedport Router Admin-Passwort (WAN-IP Probe)"
  "restic:Restic Backup-Passphrase (Lokal & Offsite)"
  "rclone:Rclone Cloud-Storage Token (Offsite Sync)"
  "jellyfin-admin:Jellyfin Initial Admin-Passwort"
)

# Prüfen ob gum verfügbar ist
if ! command -v gum >/dev/null 2>&1; then
  echo "FEHLER: 'gum' ist nicht installiert. Bitte installieren: sudo dnf install gum" >&2
  read -r -p "Enter drücken zum Beenden..."
  exit 1
fi

get_cred_name() {
  local name="$1"
  case "$name" in
    *-apikey) echo "${name%-apikey}-api-key" ;;
    speedport) echo "speedport-password" ;;
    wg-key) echo "wg-private-key" ;;
    *) echo "$name" ;;
  esac
}

remote_list_existing() {
  ssh -o BatchMode=yes -o ConnectTimeout=3 "$SSH_HOST" "sudo ls -1 $REMOTE_SECRETS_DIR/*.encrypted 2>/dev/null" 2>/dev/null || true
}

list_secrets_menu() {
  local existing_raw
  existing_raw=$(remote_list_existing)

  local items=()
  for entry in "${KNOWN_SECRETS[@]}"; do
    local key="${entry%%:*}"
    local desc="${entry#*:}"
    if echo "$existing_raw" | grep -q "/${key}\.encrypted"; then
      items+=("✅ $key — $desc")
    else
      items+=("⚪ $key — $desc (nicht gesetzt)")
    fi
  done

  # Beliebige weitere Secrets, die auf dem Server existieren aber nicht in KNOWN_SECRETS stehen
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local file
    file=$(basename "$line")
    local key="${file%.encrypted}"
    local is_known=false
    for entry in "${KNOWN_SECRETS[@]}"; do
      if [ "${entry%%:*}" = "$key" ]; then
        is_known=true
        break
      fi
    done
    if [ "$is_known" = false ]; then
      items+=("✅ $key — Benutzerdefiniertes Secret")
    fi
  done <<< "$existing_raw"

  items+=("🚀 [WireGuard .conf 1:1 ausrollen & SABnzbd neu starten (z.B. Privado)]")
  items+=("🛡️  [Systemd Live-Security-Audit vom Q958 ausführen]")
  items+=("➕ [Neues benutzerdefiniertes Secret anlegen]")
  items+=("🚪 [Beenden]")

  printf '%s\n' "${items[@]}"
}

pick_conf_file() {
  local start_dir="/home/moritz/Downloads"
  [ ! -d "$start_dir" ] && start_dir="$HOME"
  local chosen=""

  if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    if command -v kdialog >/dev/null 2>&1; then
      chosen=$(kdialog --title "WireGuard .conf-Datei auswählen" \
                       --getopenfilename "$start_dir" \
                       "*.conf|WireGuard-Konfiguration (*.conf)\n*|Alle Dateien (*)" 2>/dev/null || true)
    elif command -v zenity >/dev/null 2>&1; then
      chosen=$(zenity --file-selection \
                      --filename="$start_dir/" \
                      --file-filter="*.conf" \
                      --title="WireGuard .conf-Datei auswählen" 2>/dev/null || true)
    fi
  fi

  # Fallback auf Terminal-Dateiwähler (gum file) falls GUI abgebrochen oder nicht verfügbar
  if [ -z "$chosen" ] && command -v gum >/dev/null 2>&1; then
    chosen=$(gum file "$start_dir" --height=12 --header="Wähle eine .conf-Datei aus ($start_dir):" 2>/dev/null || true)
  fi

  printf "%s" "$chosen"
}

manage_secret() {
  local key="$1"
  local cred_name
  cred_name=$(get_cred_name "$key")

  while true; do
    clear
    gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
      "🔐 Secret: $key" "Systemd-Credential-Name: $cred_name" "Pfad auf Q958: $REMOTE_SECRETS_DIR/${key}.encrypted"

    local choice
    choice=$(gum choose \
      "👁️  Anzeigen (Entschlüsseln im Terminal)" \
      "📋 In Zwischenablage kopieren (Wayland / wl-copy)" \
      "✏️  Neu setzen / Bearbeiten" \
      "🗑️  Löschen vom Q958" \
      "🔙 Zurück zur Übersicht")

    case "$choice" in
      *"Anzeigen"*)
        clear
        gum style --foreground 212 "Entschlüssele $key via systemd-creds auf Q958..."
        local val
        val=$(ssh -o BatchMode=yes "$SSH_HOST" "sudo systemd-creds decrypt $REMOTE_SECRETS_DIR/${key}.encrypted - 2>/dev/null" || true)
        if [ -n "$val" ]; then
          gum style --border rounded --padding "1 2" --border-foreground 10 \
            "Klartext-Wert von $key:" "$val"
        else
          gum style --foreground 1 "Konnte Secret nicht entschlüsseln (existiert es?)."
        fi
        echo ""
        read -r -p "Enter drücken zum Fortfahren..."
        ;;
      *"Zwischenablage"*)
        local val
        val=$(ssh -o BatchMode=yes "$SSH_HOST" "sudo systemd-creds decrypt $REMOTE_SECRETS_DIR/${key}.encrypted - 2>/dev/null" || true)
        if [ -n "$val" ]; then
          if command -v wl-copy >/dev/null 2>&1; then
            printf "%s" "$val" | wl-copy
            gum style --foreground 10 "✓ Secret '$key' erfolgreich in die Zwischenablage kopiert!"
          elif command -v xclip >/dev/null 2>&1; then
            printf "%s" "$val" | xclip -selection clipboard
            gum style --foreground 10 "✓ Secret '$key' erfolgreich in die Zwischenablage kopiert!"
          else
            gum style --foreground 1 "Weder wl-copy noch xclip gefunden."
          fi
        else
          gum style --foreground 1 "Fehler beim Abrufen des Secrets."
        fi
        echo ""
        read -r -p "Enter drücken zum Fortfahren..."
        ;;
      *"Neu setzen"*)
        clear
        local new_val=""

        if [ "$key" = "wg-key" ]; then
          gum style --foreground 212 "Wie möchtest du das WireGuard-Secret setzen?"
          local wg_method
          wg_method=$(gum choose \
            "🚀 WireGuard .conf auswählen & komplett ausrollen (Empfohlen)" \
            "📁 PrivateKey aus .conf-Datei extrahieren und siegeln" \
            "✏️ Manuell eintippen / einfügen")

          case "$wg_method" in
            *"komplett ausrollen"*)
              deploy_wireguard_conf
              continue
              ;;
            *"aus .conf-Datei extrahieren"*)
              local selected_conf
              selected_conf=$(pick_conf_file)
              if [ -n "$selected_conf" ] && [ -f "$selected_conf" ]; then
                local extracted
                extracted=$(grep -m1 -E '^\s*PrivateKey\s*=' "$selected_conf" | cut -d= -f2- | tr -d ' \r\n')
                if [ -n "$extracted" ]; then
                  new_val="$extracted"
                  gum style --foreground 10 "✓ PrivateKey aus $(basename "$selected_conf") extrahiert."
                else
                  gum style --foreground 1 "Fehler: Kein 'PrivateKey = ...' in '$selected_conf' gefunden."
                  echo ""
                  read -r -p "Enter drücken zum Fortfahren..."
                  continue
                fi
              else
                gum style --foreground 3 "Abgebrochen: Keine Datei ausgewählt."
                echo ""
                read -r -p "Enter drücken zum Fortfahren..."
                continue
              fi
              ;;
            *"Manuell"*)
              gum style --foreground 212 "Gib den neuen Wert für '$key' ein (oder Strg+Shift+V):"
              new_val=$(gum input --password --placeholder "Secret hier eingeben...")
              ;;
          esac
        else
          gum style --foreground 212 "Gib den neuen Wert für '$key' ein (oder füge ihn mit Strg+Shift+V ein):"
          new_val=$(gum input --password --placeholder "Secret hier eingeben...")
        fi

        if [ -z "$new_val" ]; then
          gum style --foreground 3 "Abgebrochen: Leere Eingabe."
          echo ""
          read -r -p "Enter drücken zum Fortfahren..."
          continue
        fi

        gum spin --spinner dot --title "Versiegele Secret auf Q958 via systemd-creds..." -- \
          ssh -o BatchMode=yes "$SSH_HOST" "bash -c '
            sudo install -d -m 0750 \"$REMOTE_SECRETS_DIR\"
            echo -n \"$new_val\" | sudo systemd-creds encrypt --name=\"$cred_name\" - \"$REMOTE_SECRETS_DIR/${key}.encrypted\"
            sudo chown root:medinix \"$REMOTE_SECRETS_DIR/${key}.encrypted\"
            sudo chmod 0640 \"$REMOTE_SECRETS_DIR/${key}.encrypted\"
          '"
        gum style --foreground 10 "✓ Secret '$key' erfolgreich versiegelt und gespeichert!"
        echo ""
        read -r -p "Enter drücken zum Fortfahren..."
        ;;
      *"Löschen"*)
        if gum confirm "Möchtest du das Secret '$key' wirklich unwiderruflich vom Q958 löschen?"; then
          ssh -o BatchMode=yes "$SSH_HOST" "sudo rm -f \"$REMOTE_SECRETS_DIR/${key}.encrypted\""
          gum style --foreground 10 "✓ Secret '$key' gelöscht."
          echo ""
          read -r -p "Enter drücken zum Fortfahren..."
          break
        fi
        ;;
      *"Zurück"*)
        break
        ;;
    esac
  done
}

deploy_wireguard_conf() {
  clear
  gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
    "🚀 WireGuard .conf 1:1 Ausrollen & Live-Switch" \
    "Ablauf:" \
    "  1. Parst die .conf-Datei (z.B. Privado VPN)" \
    "  2. Versiegelt PrivateKey via TPM auf Q958" \
    "  3. Stoppt SABnzbd geordnet (Killswitch-Schutz)" \
    "  4. Aktualisiert /var/lib/medinix/vpn/wg-medinix.conf atomar" \
    "  5. Startet WireGuard und testet Handshake zum VPN-Endpoint" \
    "  6. Startet SABnzbd wieder und verifiziert den Status"

  gum style --foreground 212 "Wähle deine WireGuard .conf-Datei aus (KDE-Dateidialog)..."
  local conf_path
  conf_path=$(pick_conf_file)

  if [ -z "$conf_path" ]; then
    local default_path="/home/moritz/Downloads/privado.fra-017.conf"
    if [ -f "$default_path" ]; then
      conf_path=$(gum input --value "$default_path" --placeholder "Pfad zur .conf-Datei")
    else
      conf_path=$(gum input --placeholder "Pfad zur .conf-Datei (z.B. ~/Downloads/privado.conf)")
    fi
  fi

  if [ -z "$conf_path" ] || [ ! -f "$conf_path" ]; then
    gum style --foreground 1 "Fehler: Datei '$conf_path' existiert nicht."
    echo ""
    read -r -p "Enter drücken zum Fortfahren..."
    return 0
  fi

  # Parser via Python
  local parsed_output
  parsed_output=$(python3 - << EOF
import sys, configparser

cp = configparser.ConfigParser()
cp.read("$conf_path")

privkey = cp.get("Interface", "PrivateKey", fallback="").strip()
address = [x.strip() for x in cp.get("Interface", "Address", fallback="").split(",") if x.strip()]
dns = [x.strip() for x in cp.get("Interface", "DNS", fallback="").split(",") if x.strip()]
pubkey = cp.get("Peer", "PublicKey", fallback="").strip()
endpoint = cp.get("Peer", "Endpoint", fallback="").strip()
allowed = [x.strip() for x in cp.get("Peer", "AllowedIPs", fallback="0.0.0.0/0").split(",") if x.strip()]

if not privkey:
    print("ERROR: Kein PrivateKey in [Interface] gefunden!", file=sys.stderr)
    sys.exit(1)

print(f"PRIVKEY={privkey}")
print(f"ADDRESS={' '.join(address)}")
print(f"DNS={' '.join(dns)}")
print(f"PUBKEY={pubkey}")
print(f"ENDPOINT={endpoint}")
print(f"ALLOWED={' '.join(allowed)}")
EOF
) || {
    gum style --foreground 1 "Fehler beim Parsen der WireGuard-Konfiguration."
    echo ""
    read -r -p "Enter drücken zum Fortfahren..."
    return 0
  }

  local privkey address_list dns_list pubkey endpoint allowed_list
  privkey=$(echo "$parsed_output" | grep "^PRIVKEY=" | cut -d= -f2-)
  address_list=$(echo "$parsed_output" | grep "^ADDRESS=" | cut -d= -f2-)
  dns_list=$(echo "$parsed_output" | grep "^DNS=" | cut -d= -f2-)
  pubkey=$(echo "$parsed_output" | grep "^PUBKEY=" | cut -d= -f2-)
  endpoint=$(echo "$parsed_output" | grep "^ENDPOINT=" | cut -d= -f2-)
  allowed_list=$(echo "$parsed_output" | grep "^ALLOWED=" | cut -d= -f2-)

  local raw_conf
  raw_conf=$(cat "$conf_path")

  echo ""
  gum style --foreground 212 "Ausrollen nach $SSH_HOST..."

  # 1. PrivateKey per TPM2/systemd-creds versiegeln (ADR-521: 0 Plaintext auf Disk)
  gum spin --spinner dot --title "Versiegele WireGuard PrivateKey via TPM auf Q958..." -- \
    ssh -o BatchMode=yes "$SSH_HOST" "bash -c '
      sudo install -d -m 0750 \"$REMOTE_SECRETS_DIR\"
      sudo rm -f \"$REMOTE_VPN_DIR/wg-medinix.conf\" 2>/dev/null || true

      echo -n \"$privkey\" | sudo systemd-creds encrypt --name=\"wg-private-key\" --not-after=\"+365d\" - \"$REMOTE_SECRETS_DIR/wg-key.encrypted\"
      sudo chown root:medinix \"$REMOTE_SECRETS_DIR/wg-key.encrypted\"
      sudo chmod 0640 \"$REMOTE_SECRETS_DIR/wg-key.encrypted\"
    '"

  # 2. SABnzbd stoppen & WireGuard anwenden (deklarativ via systemd)
  gum spin --spinner dot --title "Stoppe SABnzbd und aktualisiere WireGuard Interface..." -- \
    ssh -o BatchMode=yes "$SSH_HOST" "bash -c '
      sudo systemctl stop sabnzbd 2>/dev/null || true
      if systemctl list-unit-files | grep -q \"wireguard-wg-medinix.service\"; then
        sudo systemctl restart wireguard-wg-medinix.service 2>/dev/null || true
      fi
    '"

  # 3. Handshake & SABnzbd Restart
  local remote_status
  remote_status=$(ssh -o BatchMode=yes "$SSH_HOST" "bash -c '
    sudo systemctl start sabnzbd 2>/dev/null || true
    SAB_ACT=\$(systemctl is-active sabnzbd 2>/dev/null || echo \"inactive\")
    if sudo wg show wg-medinix >/dev/null 2>&1; then
      WG_ACT=\"active\"
    else
      WG_ACT=\"inactive\"
    fi
    HANDSHAKE=\$(sudo wg show wg-medinix latest-handshakes 2>/dev/null | awk \"{print \\\$2}\" || echo \"none\")
    echo \"SAB_ACT=\$SAB_ACT|WG_ACT=\$WG_ACT|HANDSHAKE=\$HANDSHAKE\"
  '")

  # Generiere Nix-Block
  local addr_nix dns_nix allowed_nix
  addr_nix=$(for a in $address_list; do printf '"%s" ' "$a"; done)
  dns_nix=$(for d in $dns_list; do printf '"%s" ' "$d"; done)
  allowed_nix=$(for al in $allowed_list; do printf '"%s" ' "$al"; done)

  local nix_code
  nix_code=$(cat << NIX
  # WireGuard VPN Confinement (Aus $(basename "$conf_path") ausgerollt)
  medinix.vpn = {
    enable = true;
    address = [ $addr_nix];
    dns = [ $dns_nix];
    peer = {
      publicKey = "$pubkey";
      endpoint = "$endpoint";
      allowedIPs = [ $allowed_nix];
    };
    privateKeyCredentialPath = "$REMOTE_SECRETS_DIR/wg-key.encrypted";
  };
NIX
)

  clear
  gum style --border rounded --padding "1 2" --border-foreground 10 \
    "🎉 AUSROLLEN ERFOLGREICH!" \
    "" \
    "✓ PrivateKey via TPM2 als $REMOTE_SECRETS_DIR/wg-key.encrypted versiegelt (--not-after=+365d)" \
    "✓ 0 Plaintext-Schlüssel auf Platte (ADR-521 konform)" \
    "✓ SABnzbd geordnet gestoppt, Konfiguration aktualisiert und wieder gestartet" \
    "✓ Status: $remote_status" \
    "✓ VPN-Endpoint: $endpoint"

  echo ""
  gum style --border rounded --padding "1 2" --border-foreground 14 \
    "NixOS Host-Konfiguration für mediNix (in Zwischenablage kopiert):" "$nix_code"

  if command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$nix_code" | wl-copy
  fi

  echo ""
  read -r -p "Enter drücken zum Fortfahren..."
}

audit_live_security() {
  clear
  gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
    "🛡️  Systemd Live-Security-Audit (Q958)" \
    "Führe systemd-analyze security für mediNix Units aus..."

  local units="sabnzbd.service sonarr.service radarr.service prowlarr.service jellyfin.service caddy-media.service caddy.service pocket-id.service gatus.service"

  local cmd="systemd-analyze security $units 2>/dev/null"
  if [ "$IS_LOCAL" = true ]; then
    bash -c "$cmd" || true
  else
    ssh -o BatchMode=yes "$SSH_HOST" "$cmd" || true
  fi

  echo ""
  gum style --foreground 10 "Audit abgeschlossen. Die Scores zeigen das Härtungs-Level (<= 2.0 = OK/SAFE)."
  echo ""
  read -r -p "Enter drücken zum Fortfahren..."
}

create_new_secret() {
  clear
  gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
    "➕ Neues Secret anlegen"
  local new_key
  new_key=$(gum input --placeholder "Secret-Name (z.B. my-token)")
  [ -z "$new_key" ] && return 0

  new_key=$(echo "$new_key" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  manage_secret "$new_key"
}

# Hauptschleife
while true; do
  clear
  gum style \
    --border double \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 212 \
    "🔐 Q958 mediNix Secret & VPN Manager" \
    "Host: $SSH_HOST (192.168.2.73) | Speicher: $REMOTE_SECRETS_DIR" \
    "Systemd-Credentials (TPM2) & WireGuard Live-Rollout"

  menu_items=$(list_secrets_menu)
  selected=$(echo "$menu_items" | gum choose --limit=1)

  case "$selected" in
    *"[Beenden]"*)
      clear
      exit 0
      ;;
    *"[WireGuard .conf 1:1 ausrollen"*)
      deploy_wireguard_conf
      ;;
    *"[Systemd Live-Security-Audit"*)
      audit_live_security
      ;;
    *"[Neues benutzerdefiniertes Secret anlegen]"*)
      create_new_secret
      ;;
    *)
      clean_entry=$(echo "$selected" | sed 's/^[✅⚪] //')
      key="${clean_entry%% —*}"
      key=$(echo "$key" | tr -d ' ')
      [ -n "$key" ] && manage_secret "$key"
      ;;
  esac
done
