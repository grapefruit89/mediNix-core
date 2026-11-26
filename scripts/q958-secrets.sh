#!/usr/bin/env bash
# ==============================================================================
# Q958 mediNix Secret Manager (TUI)
# Verwaltet systemd-creds (TPM2 / Sealed) auf dem Q958 interaktiv von Nobara aus.
# Teil des mediNix-core Repositories: scripts/q958-secrets.sh
# ==============================================================================
set -euo pipefail

SSH_HOST="q958"
REMOTE_DIR="/var/lib/medinix/secrets"

# Kanonische mediNix-Secrets laut Spezifikation
KNOWN_SECRETS=(
  "cf-acme:Cloudflare ACME DNS-Token (Caddy TLS)"
  "cf-ddns:Cloudflare Dynamic DNS-Token (Blocky / WAN)"
  "wg-key:WireGuard Private Key (VPN Killswitch)"
  "sabnzbd-apikey:SABnzbd API-Schlüssel"
  "restic:Restic Backup-Passphrase"
  "jellyfin-admin:Jellyfin Initial Admin-Passwort"
  "speedport:Speedport Router Admin-Passwort (WAN-IP Probe)"
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
    *) echo "$name" ;;
  esac
}

remote_list_existing() {
  ssh -o BatchMode=yes -o ConnectTimeout=3 "$SSH_HOST" "sudo ls -1 $REMOTE_DIR/*.encrypted 2>/dev/null" 2>/dev/null || true
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

  items+=("➕ [Neues benutzerdefiniertes Secret anlegen]")
  items+=("🚪 [Beenden]")

  printf '%s\n' "${items[@]}"
}

manage_secret() {
  local key="$1"
  local cred_name
  cred_name=$(get_cred_name "$key")

  while true; do
    clear
    gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
      "🔐 Secret: $key" "Systemd-Credential-Name: $cred_name" "Pfad auf Q958: $REMOTE_DIR/${key}.encrypted"

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
        val=$(ssh -o BatchMode=yes "$SSH_HOST" "sudo systemd-creds decrypt $REMOTE_DIR/${key}.encrypted - 2>/dev/null" || true)
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
        val=$(ssh -o BatchMode=yes "$SSH_HOST" "sudo systemd-creds decrypt $REMOTE_DIR/${key}.encrypted - 2>/dev/null" || true)
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
        gum style --foreground 212 "Gib den neuen Wert für '$key' ein (oder füge ihn mit Strg+Shift+V ein):"
        local new_val
        new_val=$(gum input --password --placeholder "Secret hier eingeben...")
        if [ -z "$new_val" ]; then
          gum style --foreground 3 "Abgebrochen: Leere Eingabe."
          echo ""
          read -r -p "Enter drücken zum Fortfahren..."
          continue
        fi

        gum spin --spinner dot --title "Versiegele Secret auf Q958 via systemd-creds..." -- \
          ssh -o BatchMode=yes "$SSH_HOST" "bash -c '
            sudo install -d -m 0750 \"$REMOTE_DIR\"
            echo -n \"$new_val\" | sudo systemd-creds encrypt --name=\"$cred_name\" - \"$REMOTE_DIR/${key}.encrypted\"
            sudo chown root:medinix \"$REMOTE_DIR/${key}.encrypted\"
            sudo chmod 0640 \"$REMOTE_DIR/${key}.encrypted\"
          '"
        gum style --foreground 10 "✓ Secret '$key' erfolgreich versiegelt und gespeichert!"
        echo ""
        read -r -p "Enter drücken zum Fortfahren..."
        ;;
      *"Löschen"*)
        if gum confirm "Möchtest du das Secret '$key' wirklich unwiderruflich vom Q958 löschen?"; then
          ssh -o BatchMode=yes "$SSH_HOST" "sudo rm -f \"$REMOTE_DIR/${key}.encrypted\""
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

create_new_secret() {
  clear
  gum style --border double --margin "1" --padding "1 2" --border-foreground 212 \
    "➕ Neues Secret anlegen"
  local new_key
  new_key=$(gum input --placeholder "Secret-Name (z.B. my-token)")
  [ -z "$new_key" ] && return 0

  # Bereinigen
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
    "🔐 Q958 mediNix Secret Manager" \
    "Host: $SSH_HOST (192.168.2.73) | Speicher: $REMOTE_DIR" \
    "Systemd-Credentials (TPM2-Hardwareversiegelung)"

  menu_items=$(list_secrets_menu)
  selected=$(echo "$menu_items" | gum choose --limit=1)

  case "$selected" in
    *"[Beenden]"*)
      clear
      exit 0
      ;;
    *"[Neues benutzerdefiniertes Secret anlegen]"*)
      create_new_secret
      ;;
    *)
      # Key extrahieren: zwischen Icon (✅/⚪) und dem Gedankenstrich "—"
      clean_entry=$(echo "$selected" | sed 's/^[✅⚪] //')
      key="${clean_entry%% —*}"
      key=$(echo "$key" | tr -d ' ')
      [ -n "$key" ] && manage_secret "$key"
      ;;
  esac
done
