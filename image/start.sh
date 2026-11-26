#!/bin/bash
# Starts anfra behind a web server (Caddy), with a login page (tinyauth) in front,
# unless LOGIN_DISABLED=true, when a proxy of your own does the login.
# If any process stops, the container stops, so the host restarts it.
set -euo pipefail

fail() { echo "start.sh: $*" >&2; exit 1; }
warn() { echo "start.sh: $*" >&2; }

export PORT="${PORT:-8080}"

# The address people open. Some hosts tell the container: Render, Fly.io, Railway, Azure Container Apps.
host_url=""
if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then host_url="$RENDER_EXTERNAL_URL"
elif [ -n "${FLY_APP_NAME:-}" ]; then host_url="https://$FLY_APP_NAME.fly.dev"
elif [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then host_url="https://$RAILWAY_PUBLIC_DOMAIN"
elif [ -n "${CONTAINER_APP_NAME:-}" ] && [ -n "${CONTAINER_APP_ENV_DNS_SUFFIX:-}" ]; then
  host_url="https://$CONTAINER_APP_NAME.$CONTAINER_APP_ENV_DNS_SUFFIX"
fi
PUBLIC_URL="${PUBLIC_URL:-$host_url}"
PUBLIC_URL="${PUBLIC_URL%/}"
[ -n "$PUBLIC_URL" ] || fail "set PUBLIC_URL to the address people open, for example https://data.example.com"

# LOGIN_DISABLED=true skips the login page, for a private network (Tailscale)
# or a proxy that signs people in (Cloudflare Access).
login=on
case "${LOGIN_DISABLED:-}" in
  true|1|yes) login=off ;;
  ""|false|0|no) ;;
  *) fail "LOGIN_DISABLED must be true or false" ;;
esac

# Sign-in with Google or GitHub, through tinyauth's built-in providers. Without an allow-list,
# any Google or GitHub account could sign in, so LOGIN_ALLOWED_EMAILS is required with them.
sso=""
for p in GOOGLE GITHUB; do
  id_var="LOGIN_${p}_CLIENT_ID"; secret_var="LOGIN_${p}_CLIENT_SECRET"
  if [ -n "${!id_var:-}" ] || [ -n "${!secret_var:-}" ]; then
    [ -n "${!id_var:-}" ] && [ -n "${!secret_var:-}" ] || fail "set both $id_var and $secret_var"
    export "TINYAUTH_OAUTH_PROVIDERS_${p}_CLIENTID=${!id_var}" "TINYAUTH_OAUTH_PROVIDERS_${p}_CLIENTSECRET=${!secret_var}"
    sso="$sso ${p,,}"
  fi
  unset "$id_var" "$secret_var"
done
if [ -n "$sso" ]; then
  [ -n "${LOGIN_ALLOWED_EMAILS:-}" ] || fail "set LOGIN_ALLOWED_EMAILS, the emails that can sign in with${sso}, for example maria@example.com,lee@example.com"
  export TINYAUTH_OAUTH_WHITELIST="$LOGIN_ALLOWED_EMAILS"
fi
[ "$login" = off ] || [ -n "${LOGIN_USERS:-}" ] || [ -n "$sso" ] || fail "set LOGIN_USERS, for example alice:a-long-password,agent:another-password"

# The anfra project: your own repo from ANFRA_PROJECT_REPO, cloned here and kept up to date,
# or else the project in this image (the sample, or a folder mounted at /repo).
proj=/repo
git_auth=()
export GIT_TERMINAL_PROMPT=0
if [ -n "${ANFRA_PROJECT_REPO:-}" ]; then
  url="$ANFRA_PROJECT_REPO"
  # A repo folder mounted from the host belongs to another user. Allow it, as git would refuse.
  git config --global --add safe.directory '*'
  [[ "$url" == *://* || "$url" == git@* ]] || url="https://github.com/${url%.git}.git"
  if [ -n "${ANFRA_PROJECT_TOKEN:-}" ]; then
    git_auth+=(-c "http.extraHeader=Authorization: Basic $(printf 'x-access-token:%s' "$ANFRA_PROJECT_TOKEN" | base64 | tr -d '\n')")
  fi
  unset ANFRA_PROJECT_TOKEN
  branch=(); [ -z "${ANFRA_PROJECT_BRANCH:-}" ] || branch=(--branch "$ANFRA_PROJECT_BRANCH")
  rm -rf "$HOME/project"
  git "${git_auth[@]}" clone -q --depth 1 "${branch[@]}" "$url" "$HOME/project" 2>&1 \
    | sed 's/^/git: /' >&2 || true
  [ -d "$HOME/project/.git" ] || fail "can't clone $ANFRA_PROJECT_REPO: check the name, and for a private repo set ANFRA_PROJECT_TOKEN to a token that can read it"
  git -C "$HOME/project" rev-parse -q --verify HEAD >/dev/null || fail "$ANFRA_PROJECT_REPO has no commits yet: push your project to it first"
  proj="$HOME/project/${ANFRA_PROJECT_PATH:-}"
  proj="${proj%/}"
  [ -d "$proj" ] || fail "ANFRA_PROJECT_PATH: no folder ${ANFRA_PROJECT_PATH:-} in $ANFRA_PROJECT_REPO"
  echo "start.sh: serving $ANFRA_PROJECT_REPO at $(git -C "$HOME/project" rev-parse --short HEAD)" >&2
fi

# Database credentials, first found wins: a secret file, the ANFRA_DATA_SOURCES env var,
# the project's own file (a mounted folder), then the project's credential-free example.
mkdir -p "$proj/.anfra" 2>/dev/null || true
ds="$proj/.anfra/data_sources.yml"
example="$proj/.anfra/data_sources.yml.example"
cant_write="can't write $ds: the anfra user (uid 1000) needs write access to the project folder"
if [ -f /etc/secrets/data_sources.yml ]; then
  cat /etc/secrets/data_sources.yml > "$ds" 2>/dev/null || fail "$cant_write"
elif [ -n "${ANFRA_DATA_SOURCES:-}" ]; then
  printf '%s\n' "$ANFRA_DATA_SOURCES" > "$ds" 2>/dev/null || fail "$cant_write"
elif [ ! -f "$ds" ] && [ -f "$example" ]; then
  warn "no database credentials set, so using .anfra/data_sources.yml.example. Set ANFRA_DATA_SOURCES for your own database."
  cp "$example" "$ds" 2>/dev/null || fail "$cant_write"
fi
[ -f "$ds" ] || fail "no database credentials: add a secret file named data_sources.yml, or set ANFRA_DATA_SOURCES"
chmod 600 "$ds" 2>/dev/null || true
unset ANFRA_DATA_SOURCES

# Login users: name:password pairs. Plain passwords are hashed here, bcrypt hashes are kept.
users=""
IFS=',' read -ra pairs <<< "${LOGIN_USERS:-}"
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

# The web server's config. The host's proxy ends HTTPS and is the only thing that reaches $PORT.
# request_buffers: read the whole request before passing it on. Tailscale Serve can cut a
# streamed answer otherwise (tailscale/tailscale#21894), and MCP streams its answers.
caddyfile="$HOME/caddy/Caddyfile"
mkdir -p "$HOME/caddy"
anfra_proxy='reverse_proxy 127.0.0.1:7878 {
		header_up Host {upstream_hostport}
		request_buffers 4MB
	}'
{
  printf '{\n\tadmin off\n\tauto_https off\n\tservers {\n\t\ttrusted_proxies static 0.0.0.0/0 ::/0\n\t}\n}\n\n:{$PORT} {\n'
  if [ "$login" = off ]; then
    printf '\t%s\n' "$anfra_proxy"
  else
    # /health without a login, it shows only anfra's status and version. The login page and
    # its API (tinyauth v5.2.0 routes). Everything else is checked by tinyauth first.
    printf '\t@health path /health\n\thandle @health {\n\t\t%s\n\t}\n' "${anfra_proxy//$'\n'/$'\n\t'}"
    printf '\t@login path /login /logout /continue /totp /forgot-password /unauthorized /error /oidc/authorize /authorize /assets/* /resources/* /api/user/* /api/context/* /api/oauth/* /api/oidc/* /favicon* /apple-touch-icon.png /site.webmanifest /web-app-manifest-* /background.webp\n'
    printf '\thandle @login {\n\t\treverse_proxy 127.0.0.1:3000\n\t}\n'
    printf '\thandle {\n\t\tforward_auth 127.0.0.1:3000 {\n\t\t\turi /api/auth/caddy\n\t\t}\n\t\t%s\n\t}\n' "${anfra_proxy//$'\n'/$'\n\t'}"
  fi
  printf '}\n'
} > "$caddyfile"

cd "$proj"
ANFRA_HIDE_ERROR_CAUSES=1 ANFRA_SITE_URL="$PUBLIC_URL" \
  anfra serve --addr 127.0.0.1:7878 --no-watch &

# Pull your project's new commits every ANFRA_PROJECT_SYNC_SECONDS (default 60, 0 turns it off).
# anfra picks up changed files without a restart. Untracked files, such as data_sources.yml, stay.
sync="${ANFRA_PROJECT_SYNC_SECONDS:-60}"
if [ -n "${ANFRA_PROJECT_REPO:-}" ] && [ "$sync" != 0 ]; then
  (
    while sleep "$sync"; do
      before=$(git -C "$HOME/project" rev-parse HEAD)
      if git -C "$HOME/project" "${git_auth[@]}" fetch -q --depth 1 origin "${ANFRA_PROJECT_BRANCH:-HEAD}" 2>/dev/null \
        && git -C "$HOME/project" reset -q --hard FETCH_HEAD; then
        after=$(git -C "$HOME/project" rev-parse HEAD)
        [ "$before" = "$after" ] || warn "updated $ANFRA_PROJECT_REPO to $(git -C "$HOME/project" rev-parse --short HEAD)"
      else
        warn "can't pull $ANFRA_PROJECT_REPO, still serving $(git -C "$HOME/project" rev-parse --short HEAD)"
      fi
    done
  ) &
fi

if [ "$login" = off ]; then
  warn "LOGIN_DISABLED=true, so anyone who can reach port $PORT can use anfra"
else
  mkdir -p "$HOME/tinyauth/resources" "$HOME/tinyauth/oidc"
  # The login page's background: anfra's drawing on paper (default) or ink, or your own image URL.
  case "${LOGIN_BACKGROUND:-paper}" in
    paper|ink)
      cp "/usr/local/share/anfra-hosting/background-${LOGIN_BACKGROUND:-paper}.svg" "$HOME/tinyauth/resources/background.svg"
      background=/resources/background.svg ;;
    *) background="$LOGIN_BACKGROUND" ;;
  esac
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
  TINYAUTH_UI_BACKGROUNDIMAGE="$background" \
  TINYAUTH_UI_FORGOTPASSWORDMESSAGE="Ask the person who set up this anfra to reset your password." \
    tinyauth &
fi

caddy run --config "$caddyfile" --adapter caddyfile &

wait -n
fail "a process stopped, so the container stops too"
