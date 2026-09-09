#!/usr/bin/env bash
#
# Write site/site.json for a running Playground site.
#
# The application password is NOT created over REST. It cannot be: WordPress
# only accepts application passwords for REST Basic auth, never a user's real
# login password, so creating the first one over REST is a chicken-and-egg.
#
# Instead blueprint.json mints it in-process with a runPHP step at boot and
# writes it to /wordpress/pipeline-credential — outside wp-content, so it is
# not web-accessible. This script reads it from the host side of that mount,
# copies it into site/site.json, and deletes it.
#
# Usage:
#   ./playground-connect.sh              port from .playground.port
#   ./playground-connect.sh --port 9401

set -euo pipefail
cd "$(dirname "$0")"

say()  { printf '==> %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

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
SITE_JSON="site/site.json"
LOG=".playground.log"

# ---------------------------------------------------------------- reachable

say "Checking $URL"
curl -sf -o /dev/null --max-time 10 "$URL" \
  || die "Nothing responding at $URL.
       Is playground.sh running? Try ./playground.sh --status
       If it picked a different port, pass --port <n>."

# ------------------------------------------------- locate the mounted site

# Playground logs the host directory it mounted at /wordpress. Read the path
# from there rather than guessing at ~/.wordpress-playground/sites/<hash>.
[ -f "$LOG" ] || die "$LOG not found. Start the site with ./playground.sh first."

MOUNT="$(grep -m1 '^Mount ' "$LOG" | awk '{print $2}' || true)"
[ -n "$MOUNT" ] || die "No 'Mount' line in $LOG, so the site directory is unknown.
       Restart with ./playground.sh and try again."
[ -d "$MOUNT" ] || die "Mount path from $LOG does not exist:
       $MOUNT"

CRED="$MOUNT/pipeline-credential"
say "Site directory: $MOUNT"

# ------------------------------------------------------------- credential

[ -s "$CRED" ] || die "No credential at $CRED.
       blueprint.json should mint one with a runPHP step at boot.
       Check the step is present, then restart: ./playground.sh --stop && ./playground.sh"

APP_PASSWORD="$(tr -d '\r\n' < "$CRED")"

say "Verifying the credential"
CODE="$(curl -s -o /tmp/pg_themes.json -w '%{http_code}' \
  -u "$USER:$APP_PASSWORD" "$URL/wp-json/wp/v2/themes?status=active" || true)"
[ "$CODE" = "200" ] || die "REST returned HTTP $CODE with the minted credential.
       Body: /tmp/pg_themes.json"
say "Authenticated"

# ------------------------------------------------------------------- theme

THEME="$(grep -o '"stylesheet":"[^"]*"' /tmp/pg_themes.json | head -1 | cut -d'"' -f4 || true)"
[ -n "$THEME" ] || THEME="unknown"
say "Theme: $THEME"
[ "$THEME" = "twentytwentyfive" ] || warn "Expected twentytwentyfive — check blueprint.json ran."

# ------------------------------------------------------------ global styles

# WordPress escapes forward slashes in JSON, so the href reads
# "...\/global-styles\/5". Matching a bare "global-styles/5" never hits.
GS_ID="$(grep -o 'global-styles\\\{0,1\}/[0-9][0-9]*' /tmp/pg_themes.json \
         | head -1 | grep -o '[0-9][0-9]*' || true)"
if [ -n "$GS_ID" ]; then
  say "Global styles ID: $GS_ID"
else
  warn "No global styles record found."
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

chmod 600 "$SITE_JSON"
rm -f /tmp/pg_themes.json "$CRED"
say "Wrote $SITE_JSON and removed the staged credential"
echo
echo "    Site:  $URL"
echo "    Admin: $URL/wp-admin"
echo "    Login: admin / password   (Playground default for a local sandbox)"
