#!/usr/bin/env bash
#
# Bootstrap a WordPress block pipeline site.
#
# Works on macOS, Linux, WSL, and Windows via Git Bash. For Windows PowerShell
# use bootstrap.ps1 instead.
#
# Installs WordPress, activates the pinned theme and the receiver plugin,
# creates an application password for REST access, and writes site/site.json.
#
# Safe to re-run. It will not reinstall over an existing site, and it will not
# overwrite an existing site.json — that file holds the page and media ID maps,
# and losing them orphans every page and image already pushed.

set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found." >&2
  if [ -f env.staged.txt ]; then
    echo "Run:  cp env.staged.txt .env    then re-run this script." >&2
  else
    echo "Copy .env.example to .env and fill it in, then re-run this script." >&2
  fi
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

THEME="${WP_THEME:-twentytwentyfive}"
PLUGIN_SLUG="${PLUGIN_SLUG:-}"
WP_URL="${WP_URL:-http://localhost:${WP_PORT:-8080}}"
SITE_JSON="site/site.json"

wp() { docker compose run --rm -T wpcli "$@"; }
say()  { printf '==> %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }

# ------------------------------------------------------------------ preflight

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop (or dockerd) and try again." >&2
  exit 1
fi

say "Starting containers"
docker compose up -d db web >/dev/null

say "Waiting for the database"
for i in $(seq 1 60); do
  if wp db check >/dev/null 2>&1; then break; fi
  if [ "$i" -eq 60 ]; then
    echo >&2
    echo "The database never accepted a connection. Actual error:" >&2
    echo >&2
    wp db check 2>&1 | sed 's/^/    /' >&2
    echo >&2
    echo "Most likely causes:" >&2
    echo "  - DB_PASSWORD or DB_ROOT_PASSWORD empty in .env. Both must be set." >&2
    echo "    An empty password makes the db entrypoint skip creating the user." >&2
    echo "  - Stale volume from an earlier run with different credentials." >&2
    echo "    Fix with: docker compose down -v && docker compose up -d" >&2
    echo "    That deletes local data only." >&2
    exit 1
  fi
  sleep 1
done

# -------------------------------------------------------------------- install

if wp core is-installed >/dev/null 2>&1; then
  say "WordPress already installed, skipping install"
else
  say "Installing WordPress at $WP_URL"
  wp core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email

  say "Removing default content"
  SAMPLE="$(wp post list --post_type=page --name=sample-page --format=ids 2>/dev/null || true)"
  [ -n "$SAMPLE" ] && wp post delete "$SAMPLE" --force >/dev/null 2>&1 || true
  HELLO="$(wp post list --post_type=post --name=hello-world --format=ids 2>/dev/null || true)"
  [ -n "$HELLO" ] && wp post delete "$HELLO" --force >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------- theme

say "Activating theme: $THEME"
if ! wp theme is-installed "$THEME" >/dev/null 2>&1; then
  echo "Theme '$THEME' is not in this WordPress image." >&2
  echo "Check the pinned version bundles it, or set WP_THEME in .env." >&2
  exit 1
fi
wp theme activate "$THEME" >/dev/null

if ! wp eval 'echo wp_is_block_theme() ? "yes" : "no";' 2>/dev/null | grep -q yes; then
  echo "'$THEME' is not a block theme. The pipeline requires one." >&2
  exit 1
fi

# --------------------------------------------------------------------- plugin

if [ -n "$PLUGIN_SLUG" ] && [ -d plugin ] && [ -n "$(ls -A plugin 2>/dev/null)" ]; then
  say "Activating receiver plugin"
  wp plugin activate "$PLUGIN_SLUG" >/dev/null || warn "Could not activate '$PLUGIN_SLUG' — check its plugin header."
else
  warn "No receiver plugin in plugin/. Pushing will use core REST endpoints only."
fi

# ------------------------------------------------------------------- settings

say "Applying settings"
wp rewrite structure '/%postname%/' --hard >/dev/null
wp option update timezone_string "${WP_TIMEZONE:-UTC}" >/dev/null
wp option update blogdescription "${WP_TAGLINE:-}" >/dev/null
wp option update blog_public 0 >/dev/null   # discourage indexing locally

# ------------------------------------------------------------------ site.json

mkdir -p site/pages site/media

if [ -f "$SITE_JSON" ]; then
  say "site.json already exists — leaving it alone"
  warn "Page and media ID maps preserved. Delete it only on a genuinely fresh site."
else
  say "Creating application password"
  APP_PASSWORD="$(wp user application-password create "$WP_ADMIN_USER" pipeline --porcelain)"

  say "Reading global styles post ID"
  GLOBAL_STYLES_ID="$(wp post list --post_type=wp_global_styles --posts_per_page=1 --format=ids 2>/dev/null || true)"
  if [ -z "$GLOBAL_STYLES_ID" ]; then
    warn "No global styles post yet — it is created on first save in the Site Editor."
    warn "Open $WP_URL/wp-admin/site-editor.php, change anything, save, then re-run."
    GLOBAL_STYLES_ID="null"
  fi

  WP_VERSION="$(wp core version | tr -d '\r')"

  cat > "$SITE_JSON" <<JSON
{
  "url": "$WP_URL",
  "user": "$WP_ADMIN_USER",
  "app_password": "$APP_PASSWORD",
  "global_styles_id": $GLOBAL_STYLES_ID,
  "theme": "$THEME",
  "wp_version": "$WP_VERSION",
  "pages": {},
  "media": {}
}
JSON
  say "Wrote $SITE_JSON"
fi

# --------------------------------------------------------------------- verify

say "Checking the site responds"
if curl -sf -o /dev/null --max-time 10 "$WP_URL"; then
  say "Site is up"
else
  warn "$WP_URL did not respond."
  warn "Port already in use? Change WP_PORT in .env and re-run."
  warn "Using a .loc domain? Check Traefik: docker ps --filter name=traefik"
fi

echo
say "Done"
echo "    Site:       $WP_URL"
echo "    Admin:      $WP_URL/wp-admin  ($WP_ADMIN_USER / $WP_ADMIN_PASSWORD)"
echo "    phpMyAdmin: http://localhost:${PMA_PORT:-8081}"
echo "    Push credentials are in $SITE_JSON (gitignored)"
