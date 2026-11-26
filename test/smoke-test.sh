#!/bin/bash
# Builds the image and checks it the way a host would run it: the login page, a coding agent
# over MCP, no login when nothing is set, and a clear message for each wrong setting.
# Run from the repo root: test/smoke-test.sh (DOCKER=podman to use podman).
set -uo pipefail

DOCKER="${DOCKER:-docker}"
IMAGE=anfra-smoke-test
BASE=ghcr.io/holistics/anfra-hosting:0.24.0
HOST=anfra.test
failures=0

pass() { echo "ok   $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
check() { local name="$1"; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

# curl as the host's HTTPS proxy would forward it.
req() { curl -s -H "Host: $HOST" -H 'X-Forwarded-Proto: https' "$@"; }
mcp_init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1"}}}'
mcp_headers=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')

wait_healthy() {
  for _ in $(seq 1 90); do
    [ "$(req -o /dev/null -w '%{http_code}' "http://127.0.0.1:$1/health")" = 200 ] && return 0
    sleep 1
  done
  return 1
}

# Starts a container with a wrong setting: it must stop, with a start.sh: line that says why.
stops() {
  local name="$1" pattern="$2"; shift 2
  local logs
  logs=$("$DOCKER" run --rm "$@" "$IMAGE" 2>&1 | grep 'start.sh:' | tail -1)
  if grep -q "$pattern" <<< "$logs"; then pass "$name"; else fail "$name"; echo "  got: $logs"; fi
}

# Starts a container: it must keep running, and say this in its logs.
warns() {
  local name="$1" pattern="$2"; shift 2
  "$DOCKER" run -d --name anfra-smoke-warn "$@" "$IMAGE" >/dev/null
  sleep 8
  local logs running
  logs=$("$DOCKER" logs anfra-smoke-warn 2>&1)
  running=$("$DOCKER" inspect -f '{{.State.Running}}' anfra-smoke-warn 2>/dev/null)
  "$DOCKER" rm -f anfra-smoke-warn >/dev/null 2>&1
  if [ "$running" = true ] && grep -q "$pattern" <<< "$logs"; then pass "$name"; else fail "$name"; echo "$logs" | grep 'start.sh' | tail -3; fi
}

cleanup() { "$DOCKER" rm -f anfra-smoke-login anfra-smoke-open anfra-smoke-sso anfra-smoke-url anfra-smoke-project anfra-smoke-warn >/dev/null 2>&1; }
trap cleanup EXIT
cleanup

echo "Building the image"
"$DOCKER" build -q -t "$BASE" image >/dev/null || { echo "FAIL build of the image"; exit 1; }
"$DOCKER" build -q -t "$IMAGE" -f Dockerfile test/sample >/dev/null || { echo "FAIL build of the sample on top"; exit 1; }

echo "Built-in login, sample data source from .anfra/data_sources.yml.example"
"$DOCKER" run -d --name anfra-smoke-login -p 127.0.0.1:18090:8080 \
  -e PUBLIC_URL="https://$HOST" -e LOGIN_USERS='maria:pw-maria, agent:pw-agent' "$IMAGE" >/dev/null
if wait_healthy 18090; then
  pass "/health answers without a login"
  check "the app needs a login" [ "$(req -o /dev/null -w '%{http_code}' http://127.0.0.1:18090/)" != 200 ]
  check "MCP without a password gets 401" [ "$(req -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:18090/mcp)" = 401 ]
  sid=$(req -D - -o /dev/null -u agent:pw-agent -X POST "${mcp_headers[@]}" -d "$mcp_init" http://127.0.0.1:18090/mcp \
    | awk -F': ' 'tolower($1)=="mcp-session-id"{print $2}' | tr -d '\r')
  check "MCP initialize with the agent's password" [ -n "$sid" ]
  req -o /dev/null -u agent:pw-agent -X POST "${mcp_headers[@]}" -H "Mcp-Session-Id: $sid" \
    -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' http://127.0.0.1:18090/mcp
  tools=$(req -u agent:pw-agent -X POST "${mcp_headers[@]}" -H "Mcp-Session-Id: $sid" \
    -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' http://127.0.0.1:18090/mcp)
  check "MCP tools/list returns anfra's tools" grep -q '"name":"core.query"' <<< "$tools"
  rows=$(req -u agent:pw-agent -X POST "${mcp_headers[@]}" -H "Mcp-Session-Id: $sid" \
    -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"core.query","arguments":{"lang":"sql","data_source":"ecommerce_duckdb","query":"select count(*) as n from public.orders"}}}' \
    http://127.0.0.1:18090/mcp)
  check "an agent's SQL query returns rows from the sample database" grep -q 'records' <<< "$rows"
  check "a second user from LOGIN_USERS works" [ "$(req -o /dev/null -w '%{http_code}' -u maria:pw-maria http://127.0.0.1:18090/)" = 200 ]
  check "a wrong password gets 401" [ "$(req -o /dev/null -w '%{http_code}' -u agent:wrong -X POST http://127.0.0.1:18090/mcp)" = 401 ]
  check "the log says it used the example data source" grep -q 'using .anfra/data_sources.yml.example' <<< "$("$DOCKER" logs anfra-smoke-login 2>&1)"
else
  fail "/health never answered"; "$DOCKER" logs anfra-smoke-login 2>&1 | tail -20
fi

echo "No users: no login, for your own proxy"
"$DOCKER" run -d --name anfra-smoke-open -p 127.0.0.1:18091:8080 \
  -e PUBLIC_URL="https://$HOST" "$IMAGE" >/dev/null
if wait_healthy 18091; then
  check "the app opens without a login" [ "$(req -o /dev/null -w '%{http_code}' http://127.0.0.1:18091/)" = 200 ]
  check "MCP initialize without a password" grep -q '"serverInfo"' <<< "$(req -X POST "${mcp_headers[@]}" -d "$mcp_init" http://127.0.0.1:18091/mcp)"
else
  fail "/health never answered without users"; "$DOCKER" logs anfra-smoke-open 2>&1 | tail -20
fi

echo "Google and GitHub sign-in"
"$DOCKER" run -d --name anfra-smoke-sso -p 127.0.0.1:18092:8080 \
  -e PUBLIC_URL="https://$HOST" -e LOGIN_USERS=agent:pw-agent \
  -e LOGIN_GITHUB_CLIENT_ID=id -e LOGIN_GITHUB_CLIENT_SECRET=secret \
  -e LOGIN_GOOGLE_CLIENT_ID=id -e LOGIN_GOOGLE_CLIENT_SECRET=secret \
  -e LOGIN_ALLOWED_EMAILS=maria@example.com "$IMAGE" >/dev/null
if wait_healthy 18092; then
  # /health answers before the login page has started, so wait for it too.
  for _ in $(seq 1 20); do context=$(req http://127.0.0.1:18092/api/context/app); grep -q providers <<< "$context" && break; sleep 1; done
  check "the login page offers GitHub and Google" grep -q '"id":"github".*"id":"google"' <<< "$context"
  check "GitHub calls back to PUBLIC_URL" grep -q "redirect_uri=https%3A%2F%2F$HOST%2Fapi%2Foauth%2Fcallback%2Fgithub" <<< "$(req http://127.0.0.1:18092/api/oauth/url/github)"
else
  fail "/health never answered with Google and GitHub"; "$DOCKER" logs anfra-smoke-sso 2>&1 | tail -20
fi

echo "Your project from a git repo, kept up to date"
work=$(mktemp -d)
git init -q --bare -b main "$work/remote.git"
git -C "$work" clone -q "$work/remote.git" project 2>/dev/null
cp -r test/sample/. "$work/project/"
rm -f "$work/project/.anfra/data_sources.yml"
git -C "$work/project" add -A && git -C "$work/project" -c user.email=ci@example.com -c user.name=ci commit -qm "anfra project" && git -C "$work/project" push -q origin main
chmod -R a+rwX "$work/remote.git"
"$DOCKER" run -d --name anfra-smoke-project -p 127.0.0.1:18093:8080 -v "$work/remote.git:/srv/project.git:ro,z" \
  -e PUBLIC_URL="https://$HOST" -e ANFRA_PROJECT_REPO=file:///srv/project.git -e ANFRA_PROJECT_SYNC_SECONDS=3 "$IMAGE" >/dev/null
if wait_healthy 18093; then
  check "the project is cloned at start" grep -q 'start.sh: serving file:///srv/project.git' <<< "$("$DOCKER" logs anfra-smoke-project 2>&1)"
  printf '<!doctype html><title>Pushed later</title>\n' > "$work/project/apps/pushed-later.html"
  git -C "$work/project" add -A && git -C "$work/project" -c user.email=ci@example.com -c user.name=ci commit -qm "Add an app" && git -C "$work/project" push -q origin main
  sleep 8
  check "a new commit is pulled without a restart" "$DOCKER" exec anfra-smoke-project test -f /home/anfra/project/apps/pushed-later.html
else
  fail "/health never answered with ANFRA_PROJECT_REPO"; "$DOCKER" logs anfra-smoke-project 2>&1 | tail -20
fi
git init -q --bare "$work/empty.git"; chmod -R a+rwX "$work/empty.git"

echo "Addresses the host sets"
for host_env in FLY_APP_NAME=my-app RAILWAY_PUBLIC_DOMAIN=my-app.up.railway.app; do
  "$DOCKER" run -d --name anfra-smoke-url -e "$host_env" -e LOGIN_USERS=agent:pw "$IMAGE" >/dev/null
  sleep 5
  check "${host_env%%=*} fills PUBLIC_URL" [ "$("$DOCKER" inspect -f '{{.State.Running}}' anfra-smoke-url 2>/dev/null)" = true ]
  "$DOCKER" rm -f anfra-smoke-url >/dev/null 2>&1
done

echo "Nothing set: anfra starts without a login"
warns "no users" 'no login' -e PUBLIC_URL="https://$HOST"
warns "no PUBLIC_URL and no users" 'no login'

echo "A wrong setting stops anfra, and says what to fix"
stops "users but no PUBLIC_URL" 'set PUBLIC_URL' -e LOGIN_USERS=a:b
stops "a PUBLIC_URL without a domain" 'needs a domain name' -e PUBLIC_URL=http://localhost:8080 -e LOGIN_USERS=a:b
stops "a user without a password" "'maria' has no password" -e PUBLIC_URL="https://$HOST" -e LOGIN_USERS=maria,agent:pw
stops "GitHub without an allow-list" 'set LOGIN_ALLOWED_EMAILS' -e PUBLIC_URL="https://$HOST" -e LOGIN_GITHUB_CLIENT_ID=a -e LOGIN_GITHUB_CLIENT_SECRET=b
stops "half a Google app" 'set both LOGIN_GOOGLE_CLIENT_ID' -e PUBLIC_URL="https://$HOST" -e LOGIN_GOOGLE_CLIENT_ID=a
stops "an empty project repo" 'has no commits yet' -v "$work/empty.git:/srv/empty.git:ro,z" -e PUBLIC_URL="https://$HOST" -e ANFRA_PROJECT_REPO=file:///srv/empty.git
stops "a repo that can't be read" "can't clone" -e PUBLIC_URL="https://$HOST" -e ANFRA_PROJECT_REPO=holistics/does-not-exist-anfra

echo
[ "$failures" = 0 ] && echo "All checks passed" || { echo "$failures check(s) failed"; exit 1; }
