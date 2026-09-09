#!/usr/bin/env bash
#
# Connect this project to a live WordPress site.
#
# Creates the site/ folder structure, verifies the credentials, reads the
# global styles ID and theme off the live site, and writes site/site.live.json.
#
# Nothing is pushed and nothing on the live site is modified. This only reads.
#
# Usage:
#   ./connect.sh                                   prompts for everything
#   ./connect.sh https://example.com admin         prompts for the password only
#
# Windows PowerShell: use connect.ps1 instead.

set -euo pipefail
cd "$(dirname "$0")"

say()  { printf '==> %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is not installed."

# ----------------------------------------------------------------- gather

SITE_URL="${1:-}"
WP_USER="${2:-}"

if [ -z "$SITE_URL" ]; then
  read -rp "Site URL (e.g. https://example.com): " SITE_URL
fi
if [ -z "$WP_USER" ]; then
  read -rp "WordPress username: " WP_USER
fi

echo "Application password (from Users > Profile > Application Passwords)."
echo "Paste it including the spaces. It will not be echoed."
read -rsp "> " APP_PASSWORD
echo

[ -n "$SITE_URL" ]     || die "No site URL given."
[ -n "$WP_USER" ]      || die "No username given."
[ -n "$APP_PASSWORD" ] || die "No application password given."

# Normalise: strip trailing slash, require a scheme, warn on http
SITE_URL="${SITE_URL%/}"
case "$SITE_URL" in
  https://*) ;;
  http://*)
    warn "That URL is http, not https."
    warn "WordPress disables Application Passwords without SSL, so this will fail."
    warn "Turn on SSL first, then re-run."
    ;;
  *) die "URL must start with https:// (or http:// for a local site)." ;;
esac

AUTH="$WP_USER:$APP_PASSWORD"
OUTFILE="site/site.live.json"

# ---------------------------------------------------------------- folders

say "Creating folders"
mkdir -p site/pages site/media
echo "    site/pages/   generated page markup goes here"
echo "    site/media/   images to upload go here"

# ------------------------------------------------------------------- auth

say "Checking credentials against $SITE_URL"

HTTP_CODE="$(curl -s -o /tmp/wp_themes.json -w '%{http_code}' \
  -u "$AUTH" "$SITE_URL/wp-json/wp/v2/themes?status=active" || true)"

case "$HTTP_CODE" in
  200) say "Credentials accepted" ;;
  401) die "401 Unauthorized. The username or application password is wrong.
       Check the username is the WP login (not the email), and that the
       password was pasted whole, spaces included." ;;
  403) die "403 Forbidden. Something is blocking the REST API — often a
       security plugin or the host's firewall. On SiteGround this is usually
       mod_security and needs a support ticket." ;;
  404) die "404 Not Found. The REST API is not reachable at that URL.
       Check the address, and check permalinks are not set to Plain." ;;
  000) die "Could not reach $SITE_URL at all. Check the address and DNS." ;;
  *)   die "Unexpected response: HTTP $HTTP_CODE. Body in /tmp/wp_themes.json" ;;
esac

# ------------------------------------------------------------ theme + styles

THEME="$(grep -o '"stylesheet":"[^"]*"' /tmp/wp_themes.json | head -1 | cut -d'"' -f4 || true)"
[ -n "$THEME" ] || THEME="unknown"
say "Active theme: $THEME"

if [ "$THEME" != "twentytwentyfive" ]; then
  warn "Expected twentytwentyfive. The pipeline's markup and styles are written"
  warn "against it. Activate it in Appearance > Themes, or update WP_THEME."
fi

GLOBAL_STYLES_ID="$(grep -o 'global-styles/[0-9]\+' /tmp/wp_themes.json | head -1 | cut -d/ -f2 || true)"

if [ -z "$GLOBAL_STYLES_ID" ]; then
  warn "No global styles record found."
  warn "Open $SITE_URL/wp-admin/site-editor.php, go to Styles, change anything,"
  warn "save, then run this script again."
  GLOBAL_STYLES_ID="null"
else
  # Confirm it is actually readable, not just linked
  GS_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
    -u "$AUTH" "$SITE_URL/wp-json/wp/v2/global-styles/$GLOBAL_STYLES_ID" || true)"
  if [ "$GS_CODE" = "200" ]; then
    say "Global styles ID: $GLOBAL_STYLES_ID"
  else
    warn "Global styles ID $GLOBAL_STYLES_ID is linked but not readable (HTTP $GS_CODE)."
    warn "Save once in the Site Editor, then re-run."
    GLOBAL_STYLES_ID="null"
  fi
fi

# ---------------------------------------------------------------- version

# Not exposed over REST. Read the generator meta tag, which some security
# plugins strip — "unknown" is fine, it is only recorded for reference.
WP_VERSION="$(curl -s --max-time 10 "$SITE_URL/" \
  | grep -o 'content="WordPress [0-9.]*"' | head -1 \
  | grep -o '[0-9][0-9.]*' || true)"
[ -n "$WP_VERSION" ] || WP_VERSION="unknown"
say "WordPress version: $WP_VERSION"

if [ "$WP_VERSION" != "unknown" ]; then
  PINNED="$(grep -o 'wordpress:[0-9.]*-php' docker-compose.yml 2>/dev/null | grep -o '[0-9][0-9.]*' || true)"
  if [ -n "$PINNED" ] && [ "${WP_VERSION%%.*}.${WP_VERSION#*.}" != "$PINNED" ]; then
    case "$WP_VERSION" in
      "$PINNED"*) ;;
      *) warn "Live site is $WP_VERSION but docker-compose.yml pins $PINNED."
         warn "Your block markup was verified against $PINNED. Match them, or"
         warn "re-run the verification pass in allowed-blocks.md." ;;
    esac
  fi
fi

# --------------------------------------------------------------- write file

if [ -f "$OUTFILE" ]; then
  warn "$OUTFILE already exists."
  warn "It holds the page and media ID maps. Overwriting orphans everything"
  warn "already pushed, and the next push will create duplicates."
  read -rp "Overwrite anyway? (type yes to confirm) " CONFIRM
  [ "$CONFIRM" = "yes" ] || { say "Left alone. Nothing changed."; exit 0; }
  cp "$OUTFILE" "$OUTFILE.backup.$(date +%Y%m%d%H%M%S)"
  say "Backed up the old one first"
fi

cat > "$OUTFILE" <<JSON
{
  "url": "$SITE_URL",
  "user": "$WP_USER",
  "app_password": "$APP_PASSWORD",
  "global_styles_id": $GLOBAL_STYLES_ID,
  "theme": "$THEME",
  "wp_version": "$WP_VERSION",
  "pages": {},
  "media": {}
}
JSON

say "Wrote $OUTFILE"

# ---------------------------------------------------------------- gitignore

touch .gitignore
for LINE in "site/site.json" "site/site.live.json" "site/site.*.json.backup.*"; do
  grep -qxF "$LINE" .gitignore 2>/dev/null || echo "$LINE" >> .gitignore
done
say "Credentials excluded from git"

rm -f /tmp/wp_themes.json

echo
say "Connected"
echo "    Site:   $SITE_URL"
echo "    Config: $OUTFILE"
echo
if [ "$GLOBAL_STYLES_ID" = "null" ]; then
  echo "    Save once in the Site Editor and re-run before pushing styles."
else
  echo "    Ready to push. Styles first, then media, then pages."
fi
