#!/bin/sh
set -eu

# 1. Runtime defaults
WEBROOT="${CERTBOT_WEBROOT:-/var/www/certbot}"
RENEW_INTERVAL="${CERTBOT_RENEW_INTERVAL:-12h}"
NGINX_CONTAINER="${NGINX_CONTAINER:-nginx}"
DH_BITS="${STRONG_DH:+4096}"
DH_BITS="${DH_BITS:-2048}"

# 2. Reload Nginx after a certificate was actually renewed
reload_nginx() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[certbot] docker CLI not found; nginx reload skipped" >&2
    return 1
  fi

  echo "[certbot] reloading nginx container: ${NGINX_CONTAINER}"
  docker exec "${NGINX_CONTAINER}" nginx -s reload
}

# 3. Deploy-hook entrypoint
if [ "${1:-}" = "reload" ]; then
  reload_nginx
  exit $?
fi

# 4. Create TLS helper files required by Nginx SSL server blocks
ensure_tls_defaults() {
  if [ ! -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
    echo "[certbot] creating options-ssl-nginx.conf"
    curl -fsSL \
      https://raw.githubusercontent.com/certbot/certbot/main/certbot-nginx/src/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
      -o /etc/letsencrypt/options-ssl-nginx.conf
  fi

  if [ ! -f /etc/letsencrypt/ssl-dhparams.pem ]; then
    echo "[certbot] creating ssl-dhparams.pem (${DH_BITS}bit)"
    openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem "${DH_BITS}"
  fi
}

# 5. Stop cleanly when Docker asks the container to exit
trap 'echo "[certbot] stopping"; exit 0' TERM INT

# 6. Run certbot renewal checks forever
while :; do
  ensure_tls_defaults

  echo "[certbot] renewal check started"
  certbot renew \
    --webroot -w "${WEBROOT}" \
    --quiet \
    --disable-hook-validation \
    --deploy-hook "/usr/local/bin/renew-loop.sh reload"
  echo "[certbot] renewal check finished; sleeping ${RENEW_INTERVAL}"

  # 7. Sleep in a signal-friendly way
  sleep "${RENEW_INTERVAL}" &
  wait "$!"
done
