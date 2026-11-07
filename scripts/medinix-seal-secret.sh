#!/usr/bin/env bash
# Seal a secret for LoadCredentialEncrypted. No sops.
#   sudo ./medinix-seal-secret.sh sabnzbd-apikey
#   # then type the secret, EOF
# or: echo -n 'secret' | sudo ./medinix-seal-secret.sh sabnzbd-apikey
#
# ── KONVENTION: Dateiname vs. Credential-Name ────────────────────────────────
#   Datei       : <dir>/<NAME>.encrypted         (NAME genau wie uebergeben)
#   Credential  : NAME                            fuer alle Namen
#                 <basis>-api-key                 fuer Namen auf "-apikey"
#
# Warum das noetig ist: systemd bettet den Credential-Namen IN den Blob ein.
# Die Units schreiben `LoadCredentialEncrypted = "sonarr-api-key:<datei>"`.
# Wer also mit `--name=sonarr-apikey` versiegelt, bekommt beim Start
#   "Name in credential doesn't match expectations" (status=243/CREDENTIALS).
# Das Suffix-Mapping betrifft AUSSCHLIESSLICH "-apikey"; alle anderen Namen
# (z.B. "cf-acme", "wg-key", "jellyfin-admin") bleiben unveraendert.
#
# Override fuer Tests: SECRETS_DIR=/tmp/sealtest ./medinix-seal-secret.sh ...
set -euo pipefail
name=${1:-}
if [ -z "$name" ]; then
  echo "usage: $0 NAME" >&2
  echo "  Datei       : <dir>/NAME.encrypted" >&2
  echo "  Credential  : NAME  (bei NAME auf '-apikey': <basis>-api-key)" >&2
  exit 1
fi

cred="$name"
case "$name" in
  *-apikey) cred="${name%-apikey}-api-key" ;;
esac

dir="${SECRETS_DIR:-/var/lib/medinix/secrets}"
install -d -m 0750 "$dir"
out="$dir/${name}.encrypted"
systemd-creds encrypt --name="$cred" - "$out"
chmod 0640 "$out"
echo "sealed $out"
echo "credential name: $cred"
echo "set the matching medinix option to this path"
