#!/bin/sh
# Usage: ./make-config-b64.sh my-config.toml
# Prints the single-line base64 value for EMAIL_MCP_CONFIG_TOML_B64.
# Run locally; never commit your real config.
set -eu
f="${1:-config.toml}"
if base64 --help 2>&1 | grep -q -- '-w'; then base64 -w0 "$f"; else base64 < "$f" | tr -d '\n'; fi
echo
