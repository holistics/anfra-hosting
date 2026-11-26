#!/bin/bash
# Starts anfra, the login page (tinyauth) and the web server (Caddy).
# If any of them stops, the container stops, so the platform restarts it.
set -euo pipefail

fail() { echo "start.sh: $*" >&2; exit 1; }

export PORT="${PORT:-8080}"
PUBLIC_URL="${PUBLIC_URL:-${RENDER_EXTERNAL_URL:-}}"
PUBLIC_URL="${PUBLIC_URL%/}"
[ -n "$PUBLIC_URL" ] || fail "set PUBLIC_URL to the address people open, for example https://data.example.com"
[ -n "${LOGIN_USERS:-}" ] || fail "set LOGIN_USERS, for example alice:a-long-password,agent:another-password"

# Database credentials: a secret file, or the ANFRA_DATA_SOURCES env var.
ds=/repo/.anfra/data_sources.yml
# A secret file wins over the env var. A project mounted with its own file needs neither.
cant_write="can't write $ds: the anfra user (uid 1000) needs write access to the project folder"
if [ -f /etc/secrets/data_sources.yml ]; then
  cat /etc/secrets/data_sources.yml > "$ds" 2>/dev/null || fail "$cant_write"
elif [ -n "${ANFRA_DATA_SOURCES:-}" ]; then
  printf '%s\n' "$ANFRA_DATA_SOURCES" > "$ds" 2>/dev/null || fail "$cant_write"
fi
[ -f "$ds" ] || fail "no database credentials: add a secret file named data_sources.yml, or set ANFRA_DATA_SOURCES"
chmod 600 "$ds" 2>/dev/null || true
unset ANFRA_DATA_SOURCES

# Login users: name:password pairs. Plain passwords are hashed here, bcrypt hashes are kept.
users=""
IFS=',' read -ra pairs <<< "$LOGIN_USERS"
for pair in "${pairs[@]}"; do
  pair="${pair#"${pair%%[![:space:]]*}"}"; pair="${pair%"${pair##*[![:space:]]}"}"
  [ -n "$pair" ] || continue
  name="${pair%%:*}"; pass="${pair#*:}"
  [ -n "$name" ] && [ "$pass" != "$pair" ] && [ -n "$pass" ] || fail "LOGIN_USERS must look like name:password,name2:password2"
  if [[ "$pass" != \$2* ]]; then
    pass="$(tinyauth user create --username "$name" --password "$pass" 2>/dev/null | grep -o "$name:\$2[./A-Za-z0-9\$]*" | head -1)"
    pass="${pass#*:}"
    [ -n "$pass" ] || fail "could not hash the password for $name"
  fi
  users="${users:+$users,}$name:$pass"
done
unset LOGIN_USERS

mkdir -p "$HOME/tinyauth/resources" "$HOME/tinyauth/oidc"

ANFRA_HIDE_ERROR_CAUSES=1 ANFRA_SITE_URL="$PUBLIC_URL" \
  anfra serve --addr 127.0.0.1:7878 --no-watch &

TINYAUTH_APPURL="$PUBLIC_URL" \
TINYAUTH_AUTH_USERS="$users" \
TINYAUTH_AUTH_SUBDOMAINSENABLED=false \
TINYAUTH_AUTH_SECURECOOKIE=true \
TINYAUTH_SERVER_ADDRESS=127.0.0.1 \
TINYAUTH_SERVER_PORT=3000 \
TINYAUTH_DATABASE_PATH="$HOME/tinyauth/tinyauth.db" \
TINYAUTH_RESOURCES_PATH="$HOME/tinyauth/resources" \
TINYAUTH_OIDC_PRIVATEKEYPATH="$HOME/tinyauth/oidc/key.pem" \
TINYAUTH_OIDC_PUBLICKEYPATH="$HOME/tinyauth/oidc/key.pub" \
TINYAUTH_UI_TITLE="${LOGIN_TITLE:-anfra}" \
TINYAUTH_UI_FORGOTPASSWORDMESSAGE="Ask the person who set up this anfra to reset your password." \
  tinyauth &

caddy run --config /repo/deploy/Caddyfile --adapter caddyfile &

wait -n
fail "a process stopped, so the container stops too"
