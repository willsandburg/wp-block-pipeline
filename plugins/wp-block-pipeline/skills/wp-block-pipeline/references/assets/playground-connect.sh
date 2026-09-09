#!/usr/bin/env bash
#
# Write site/site.json for a running Playground site.
#
# Run this in a SECOND terminal while playground.sh is running in the first.
#
# Playground has no WP-CLI, so the application password is created through the
# REST API using the admin login the Playground CLI sets up (admin/password).
#
# Usage:
#   ./playground-connect.sh              assumes port 9400
#   ./playground-connect.sh --port 9401

set -euo pipefail
cd "$(dirname "$0")"

say()  { printf '==> %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# playground.sh records the port it actually bound to, since it moves up if the
# preferred one is taken.
PORT=9400
[ -f .playground.port ] && PORT="$(cat .playground.port)"
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    *) die "Unknown option: $1" ;;
  esac
done

URL="http://127.0.0.1:$PORT"
USER="admin"
PASS="password"
SITE_JSON="site/site.json"

# ---------------------------------------------------------------- reachable

say "Checking $URL"
curl -sf -o /dev/null --max-time 10 "$URL" \
  || die "Nothing responding at $URL.
       Is playground.sh running in another terminal?
       If it picked a different port, pass --port <n>."

# --------------------------------------------------------------------- auth

CODE="$(curl -s -o /tmp/pg_themes.json -w '%{http_code}' \
  -u "$USER:$PASS" "$URL/wp-json/wp/v2/themes?status=active" || true)"

if [ "$CODE" != "200" ]; then
  die "REST returned HTTP $CODE using the default admin login.
       If you changed the admin password in the Playground site, this script
       needs updating. Body: /tmp/pg_themes.json"
fi
say "Authenticated"

THEME="$(grep -o '"stylesheet":"[^"]*"' /tmp/pg_themes.json | head -1 | cut -d'"' -f4 || true)"
[ -n "$THEME" ] || THEME="unknown"
say "Theme: $THEME"
[ "$THEME" = "twentytwentyfive" ] || warn "Expected twentytwentyfive — check blueprint.json ran."

# ---------------------------------------------------- application password

# Requires WP_ENVIRONMENT_TYPE=local, which blueprint.json sets. Without it
# WordPress refuses to issue application passwords over plain http.
say "Creating application password"
APP_JSON="$(curl -s -u "$USER:$PASS" \
  -X POST "$URL/wp-json/wp/v2/users/me/application-passwords" \
  -H "Content-Type: application/json" \
  -d '{"name":"pipeline"}' || true)"

APP_PASSWORD="$(echo "$APP_JSON" | grep -o '"password":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"

if [ -z "$APP_PASSWORD" ]; then
  warn "Could not create an application password."
  warn "Usually means WP_ENVIRONMENT_TYPE is not 'local' — check blueprint.json."
  warn "Falling back to the admin login, which works fine locally."
  APP_PASSWORD="$PASS"
fi

# ------------------------------------------------------------ global styles

GS_ID="$(grep -o 'global-styles/[0-9]\+' /tmp/pg_themes.json | head -1 | cut -d/ -f2 || true)"
if [ -n "$GS_ID" ]; then
  say "Global styles ID: $GS_ID"
else
  warn "No global styles record yet."
  warn "Open $URL/wp-admin/site-editor.php, change any style, save, re-run."
  GS_ID="null"
fi

WP_VERSION="$(curl -s "$URL/" | grep -o 'content="WordPress [0-9.]*"' | head -1 | grep -o '[0-9][0-9.]*' || true)"
[ -n "$WP_VERSION" ] || WP_VERSION="unknown"
say "WordPress $WP_VERSION"

# --------------------------------------------------------------- write file

mkdir -p site
if [ -f "$SITE_JSON" ]; then
  warn "$SITE_JSON exists and holds the page and media ID maps."
  read -rp "Overwrite? (type yes) " C
  [ "$C" = "yes" ] || { say "Left alone."; exit 0; }
  cp "$SITE_JSON" "$SITE_JSON.backup.$(date +%Y%m%d%H%M%S)"
fi

cat > "$SITE_JSON" <<JSON
{
  "url": "$URL",
  "user": "$USER",
  "app_password": "$APP_PASSWORD",
  "global_styles_id": $GS_ID,
  "theme": "$THEME",
  "wp_version": "$WP_VERSION",
  "environment": "playground",
  "pages": {},
  "media": {}
}
JSON

rm -f /tmp/pg_themes.json
say "Wrote $SITE_JSON"
echo
echo "    Site:  $URL"
echo "    Admin: $URL/wp-admin  ($USER / $PASS)"
