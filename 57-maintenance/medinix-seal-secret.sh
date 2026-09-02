#!/usr/bin/env bash
# Seal a secret for LoadCredentialEncrypted. No sops.
#   sudo ./medinix-seal-secret.sh sabnzbd-apikey
#   # then type the secret, EOF
# or: echo -n 'secret' | sudo ./medinix-seal-secret.sh sabnzbd-apikey
set -euo pipefail
name=${1:-}
if [ -z "$name" ]; then
  echo "usage: $0 NAME" >&2
  echo "writes /var/lib/medinix/secrets/NAME.encrypted" >&2
  exit 1
fi
dir=/var/lib/medinix/secrets
install -d -m 0750 "$dir"
out="$dir/${name}.encrypted"
systemd-creds encrypt --name="$name" - "$out"
chmod 0640 "$out"
echo "sealed $out"
echo "set the matching medinix option to this path"
