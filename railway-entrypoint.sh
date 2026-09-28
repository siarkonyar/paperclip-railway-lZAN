#!/bin/sh
# Runs as CMD, i.e. already as `node` (see Dockerfile). Never run it as root.
set -e

# The template pre-fills provider keys with a placeholder so Railway doesn't mark
# them required. Any non-empty value counts as a real key to the agent CLIs (and
# ANTHROPIC_API_KEY overrides a Claude subscription token), so drop placeholders.
for name in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY; do
  eval "value=\${$name-}"
  case "$value" in
    ""|OPTIONAL_*|\"OPTIONAL_*) unset "$name" ;;
  esac
done

home_dir="${PAPERCLIP_HOME:-/paperclip}"
instance_dir="$home_dir/instances/${PAPERCLIP_INSTANCE_ID:-default}"
config_path="${PAPERCLIP_CONFIG:-$instance_dir/config.json}"
# A template variable like https://${{RAILWAY_PUBLIC_DOMAIN}} renders as a bare
# "https://" (or nothing) when the service had no domain yet, so treat that as
# unset and fall back to the domain Railway injects at runtime.
is_url() { case "$1" in http://?*|https://?*) return 0 ;; *) return 1 ;; esac; }
public_url=""
for candidate in "$PAPERCLIP_AUTH_PUBLIC_BASE_URL" "$PAPERCLIP_PUBLIC_URL" "${RAILWAY_PUBLIC_DOMAIN:+https://$RAILWAY_PUBLIC_DOMAIN}"; do
  if is_url "$candidate"; then public_url="${candidate%/}"; break; fi
done

if [ -z "$public_url" ]; then
  echo "railway-entrypoint: no public URL. In Railway, open this service → Settings → Networking → Generate Domain (port 3100), then redeploy." >&2
  exit 1
fi

# The server and the bootstrap CLI read these directly; keep them consistent.
export PAPERCLIP_PUBLIC_URL="$public_url" PAPERCLIP_AUTH_PUBLIC_BASE_URL="$public_url"

# The server runs from env alone, but `paperclipai auth bootstrap-ceo` refuses to
# run without a config file. Paths are absolute on purpose: the schema defaults
# use "~/.paperclip/...", which with HOME=/paperclip would relocate data.
if [ ! -f "$config_path" ]; then
  mkdir -p "$(dirname "$config_path")"
  cat > "$config_path" <<EOF
{
  "\$meta": { "version": 1, "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "source": "onboard" },
  "database": {
    "mode": "postgres",
    "backup": { "enabled": true, "intervalMinutes": 60, "retentionDays": 7, "dir": "$instance_dir/data/backups" }
  },
  "logging": { "mode": "file", "logDir": "$instance_dir/logs" },
  "server": {
    "deploymentMode": "authenticated",
    "exposure": "public",
    "host": "0.0.0.0",
    "port": ${PORT:-3100},
    "serveUi": true
  },
  "telemetry": { "enabled": true },
  "storage": { "provider": "local_disk", "localDisk": { "baseDir": "$instance_dir/data/storage" } },
  "secrets": { "provider": "local_encrypted", "strictMode": false, "localEncrypted": { "keyFilePath": "$instance_dir/secrets/master.key" } }
}
EOF
  echo "railway-entrypoint: wrote initial config to $config_path"
fi

# The file is validated on its own (env overrides apply only after parsing), and
# public mode demands an explicit auth URL in it. Refresh it every boot so a
# domain change in Railway variables can't leave a stale value behind.
tmp_config="$config_path.tmp"
jq --arg url "$public_url" '.auth = ((.auth // {}) + {baseUrlMode: "explicit", publicBaseUrl: $url})' \
  "$config_path" > "$tmp_config" && mv "$tmp_config" "$config_path"

# Until an instance admin exists, mint a bootstrap-CEO invite and print it to
# the deploy logs. Each restart while pending revokes the previous invite.
bootstrap_first_admin() {
  port="${PORT:-3100}"
  attempts=0
  until status=$(curl -fsS "http://127.0.0.1:$port/api/health" 2>/dev/null | jq -r '.bootstrapStatus // empty'); [ -n "$status" ]; do
    attempts=$((attempts + 1))
    [ "$attempts" -ge 120 ] && { echo "railway-entrypoint: server never became healthy; skipping bootstrap invite" >&2; return 0; }
    sleep 5
  done
  [ "$status" = "bootstrap_pending" ] || return 0

  echo "=================================================================="
  echo " Paperclip has no admin yet. Open the invite URL below to become"
  echo " the CEO/owner of this instance (expires in 72h; redeploy for a new one)."
  echo "=================================================================="
  cd /app && node cli/node_modules/tsx/dist/cli.mjs cli/src/index.ts auth bootstrap-ceo
}

# Double fork so tini (PID 1) reaps the helper instead of the node server.
( bootstrap_first_admin & )

exec "$@"
