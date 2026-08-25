#!/usr/bin/env bash
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./medinix-seal-secret.sh <SecretName> <SecretValue>"
  exit 1
fi
echo -n "$2" | sudo systemd-creds encrypt --name="$1" - "/var/lib/medinix/secrets/$1.encrypted"
echo "Secret '$1' encrypted successfully to /var/lib/medinix/secrets/$1.encrypted"
