#!/usr/bin/env bash
# DSPy-style Hard Assertion for Portability
FILE=$1

if [ -z "$FILE" ]; then
    echo "Usage: assert_no_ips.sh <file>"
    exit 1
fi

echo "Running Portability Assertion on $FILE..."

# Check for hardcoded 192.168.*.* or 10.*.*.*
if grep -E -q '(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+)' "$FILE"; then
    echo "FAIL: Hardcoded LAN IP found in $FILE! This violates portability rules."
    echo "Fix this by using options (e.g., config.grapefruitMedia...) or 127.0.0.1 where applicable."
    exit 1
fi

echo "PASS: No hardcoded LAN IPs found."
exit 0
