#!/bin/sh
# Render entrypoint for email-mcp (Streamable HTTP).
#  - refuses to start without a strong bearer token
#  - materialises config.toml from an env var or a Render Secret File
#  - binds 0.0.0.0:$PORT, MCP at $EMAIL_MCP_HTTP_PATH (default /mcp),
#    unauthenticated GET /healthz for health checks / keep-alive pings
set -eu

log() { printf '[render-entrypoint] %s\n' "$*" >&2; }

# ---- 1. Auth ---------------------------------------------------------------
TOKEN="${EMAIL_MCP_HTTP_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  log "FATAL: EMAIL_MCP_HTTP_TOKEN is not set. Refusing to expose the mail server without auth."
  exit 1
fi
if [ "${#TOKEN}" -lt 32 ]; then
  log "FATAL: EMAIL_MCP_HTTP_TOKEN must be at least 32 characters."
  exit 1
fi

# ---- 2. Config -------------------------------------------------------------
# Priority: EMAIL_MCP_CONFIG_TOML_B64 > EMAIL_MCP_CONFIG_TOML
#           > $EMAIL_MCP_CONFIG_FILE (default /etc/secrets/config.toml)
#           > single-account MCP_EMAIL_* env vars (handled by the app itself)
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/email-mcp"
CONF="$CONF_DIR/config.toml"
SECRET_FILE="${EMAIL_MCP_CONFIG_FILE:-/etc/secrets/config.toml}"
mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR" 2>/dev/null || true
umask 077

if [ -n "${EMAIL_MCP_CONFIG_TOML_B64:-}" ]; then
  printf '%s' "$EMAIL_MCP_CONFIG_TOML_B64" | tr -d ' \r\n' | base64 -d > "$CONF" \
    || { log "FATAL: EMAIL_MCP_CONFIG_TOML_B64 is not valid base64"; exit 1; }
  log "config.toml written from EMAIL_MCP_CONFIG_TOML_B64"
elif [ -n "${EMAIL_MCP_CONFIG_TOML:-}" ]; then
  printf '%s\n' "$EMAIL_MCP_CONFIG_TOML" > "$CONF"
  log "config.toml written from EMAIL_MCP_CONFIG_TOML"
elif [ -r "$SECRET_FILE" ]; then
  cp "$SECRET_FILE" "$CONF"
  log "config.toml copied from $SECRET_FILE"
elif [ -n "${MCP_EMAIL_ADDRESS:-}" ]; then
  log "no config.toml supplied; using single-account MCP_EMAIL_* env vars"
else
  log "FATAL: no configuration. Set EMAIL_MCP_CONFIG_TOML_B64 / EMAIL_MCP_CONFIG_TOML," \
      "add a Secret File named config.toml, or set MCP_EMAIL_* vars."
  exit 1
fi
[ -f "$CONF" ] && chmod 600 "$CONF"

# The app prefers MCP_EMAIL_* env over the file; warn so nobody gets surprised.
if [ -f "$CONF" ] && [ -n "${MCP_EMAIL_ADDRESS:-}" ] && [ -n "${MCP_EMAIL_IMAP_HOST:-}" ]; then
  log "WARNING: MCP_EMAIL_ADDRESS/IMAP_HOST are set - the app will IGNORE config.toml. Unset them."
fi

# ---- 3. Host-header allowlist (DNS-rebinding guard) ------------------------
# Render sets RENDER_EXTERNAL_HOSTNAME (e.g. email-mcp-xxxx.onrender.com).
if [ -z "${EMAIL_MCP_HTTP_ALLOWED_HOSTS:-}" ]; then
  if [ -n "${RENDER_EXTERNAL_HOSTNAME:-}" ]; then
    EMAIL_MCP_HTTP_ALLOWED_HOSTS="${RENDER_EXTERNAL_HOSTNAME},localhost,127.0.0.1"
  else
    EMAIL_MCP_HTTP_ALLOWED_HOSTS="*"   # token still enforced
  fi
  export EMAIL_MCP_HTTP_ALLOWED_HOSTS
fi

# ---- 4. Run ----------------------------------------------------------------
# The token is passed via env (EMAIL_MCP_HTTP_TOKEN), never argv.
export EMAIL_MCP_HTTP_HOST=0.0.0.0
export EMAIL_MCP_HTTP_PORT="${PORT:-10000}"
export EMAIL_MCP_HTTP_PATH="${EMAIL_MCP_HTTP_PATH:-/mcp}"
log "starting email-mcp http on 0.0.0.0:${EMAIL_MCP_HTTP_PORT}${EMAIL_MCP_HTTP_PATH} (allowed hosts: ${EMAIL_MCP_HTTP_ALLOWED_HOSTS})"
exec node "${EMAIL_MCP_MAIN:-/app/dist/main.js}" http "$@"
