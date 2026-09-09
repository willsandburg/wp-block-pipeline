<#
    Bootstrap a WordPress block pipeline site. Windows PowerShell.

    Equivalent to bootstrap.sh. Use that one instead if you have Git Bash or
    WSL — it is the version that gets tested first.

    Installs WordPress, activates the pinned theme and the receiver plugin,
    creates an application password for REST access, and writes site/site.json.

    Safe to re-run. It will not reinstall over an existing site, and it will not
    overwrite an existing site.json — that file holds the page and media ID
    maps, and losing them orphans every page and image already pushed.

    Usage:  .\bootstrap.ps1

    If PowerShell refuses to run it:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Say  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "  ! $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host $m -ForegroundColor Red; exit 1 }

# ------------------------------------------------------------------------ env

if (-not (Test-Path .env)) { Die "No .env found. Copy .env.example to .env first." }

$env_vars = @{}
Get-Content .env | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $k, $v = $line.Split('=', 2)
        $env_vars[$k.Trim()] = $v.Trim().Trim('"')
    }
}

function Cfg { param($key, $default = '') 
    if ($env_vars.ContainsKey($key) -and $env_vars[$key]) { $env_vars[$key] } else { $default } }

$THEME        = Cfg 'WP_THEME' 'twentytwentyfive'
$PLUGIN_SLUG  = Cfg 'PLUGIN_SLUG'
$WP_PORT      = Cfg 'WP_PORT' '8080'
$PMA_PORT     = Cfg 'PMA_PORT' '8081'
$WP_URL       = Cfg 'WP_URL' "http://localhost:$WP_PORT"
$WP_TITLE     = Cfg 'WP_TITLE' 'Site'
$ADMIN_USER   = Cfg 'WP_ADMIN_USER' 'admin'
$ADMIN_PASS   = Cfg 'WP_ADMIN_PASSWORD' 'admin'
$ADMIN_EMAIL  = Cfg 'WP_ADMIN_EMAIL' 'admin@example.com'
$TIMEZONE     = Cfg 'WP_TIMEZONE' 'UTC'
$TAGLINE      = Cfg 'WP_TAGLINE'
$SITE_JSON    = 'site/site.json'

function Wp {
    # -T avoids TTY allocation, which PowerShell does not provide
    $out = docker compose run --rm -T wpcli @args 2>&1
    return @{ ok = ($LASTEXITCODE -eq 0); out = ($out | Out-String).Trim() }
}

# ------------------------------------------------------------------ preflight

docker info *> $null
if ($LASTEXITCODE -ne 0) { Die "Docker is not running. Start Docker Desktop and try again." }

Say "Starting containers"
docker compose up -d db web *> $null

Say "Waiting for the database"
$ready = $false
foreach ($i in 1..60) {
    if ((Wp 'db' 'check').ok) { $ready = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $ready) { Die "Database did not become ready in 60s. Check: docker compose logs db" }

# -------------------------------------------------------------------- install

if ((Wp 'core' 'is-installed').ok) {
    Say "WordPress already installed, skipping install"
} else {
    Say "Installing WordPress at $WP_URL"
    $r = Wp 'core' 'install' "--url=$WP_URL" "--title=$WP_TITLE" `
        "--admin_user=$ADMIN_USER" "--admin_password=$ADMIN_PASS" `
        "--admin_email=$ADMIN_EMAIL" '--skip-email'
    if (-not $r.ok) { Die "Install failed:`n$($r.out)" }

    Say "Removing default content"
    $sample = (Wp 'post' 'list' '--post_type=page' '--name=sample-page' '--format=ids').out
    if ($sample) { Wp 'post' 'delete' $sample '--force' | Out-Null }
    $hello = (Wp 'post' 'list' '--post_type=post' '--name=hello-world' '--format=ids').out
    if ($hello) { Wp 'post' 'delete' $hello '--force' | Out-Null }
}

# ---------------------------------------------------------------------- theme

Say "Activating theme: $THEME"
if (-not (Wp 'theme' 'is-installed' $THEME).ok) {
    Die "Theme '$THEME' is not in this WordPress image. Check the pinned version, or set WP_THEME in .env."
}
Wp 'theme' 'activate' $THEME | Out-Null

$isBlock = (Wp 'eval' 'echo wp_is_block_theme() ? "yes" : "no";').out
if ($isBlock -notmatch 'yes') { Die "'$THEME' is not a block theme. The pipeline requires one." }

# --------------------------------------------------------------------- plugin

if ($PLUGIN_SLUG -and (Test-Path plugin) -and (Get-ChildItem plugin -Force | Select-Object -First 1)) {
    Say "Activating receiver plugin"
    if (-not (Wp 'plugin' 'activate' $PLUGIN_SLUG).ok) {
        Warn "Could not activate '$PLUGIN_SLUG' — check its plugin header."
    }
} else {
    Warn "No receiver plugin in plugin/. Pushing will use core REST endpoints only."
}

# ------------------------------------------------------------------- settings

Say "Applying settings"
Wp 'rewrite' 'structure' '/%postname%/' '--hard' | Out-Null
Wp 'option' 'update' 'timezone_string' $TIMEZONE | Out-Null
Wp 'option' 'update' 'blogdescription' $TAGLINE  | Out-Null
Wp 'option' 'update' 'blog_public' '0'           | Out-Null

# ------------------------------------------------------------------ site.json

New-Item -ItemType Directory -Force -Path site/pages, site/media | Out-Null

if (Test-Path $SITE_JSON) {
    Say "site.json already exists — leaving it alone"
    Warn "Page and media ID maps preserved. Delete it only on a genuinely fresh site."
} else {
    Say "Creating application password"
    $appPassword = (Wp 'user' 'application-password' 'create' $ADMIN_USER 'pipeline' '--porcelain').out

    Say "Reading global styles post ID"
    $gsId = (Wp 'post' 'list' '--post_type=wp_global_styles' '--posts_per_page=1' '--format=ids').out
    if (-not $gsId) {
        Warn "No global styles post yet — it is created on first save in the Site Editor."
        Warn "Open $WP_URL/wp-admin/site-editor.php, change anything, save, then re-run."
        $gsId = 'null'
    }

    $wpVersion = (Wp 'core' 'version').out

    $json = @"
{
  "url": "$WP_URL",
  "user": "$ADMIN_USER",
  "app_password": "$appPassword",
  "global_styles_id": $gsId,
  "theme": "$THEME",
  "wp_version": "$wpVersion",
  "pages": {},
  "media": {}
}
"@
    # No BOM. PowerShell's default UTF8 encoding adds one and breaks JSON parsers.
    [System.IO.File]::WriteAllText(
        (Join-Path $PSScriptRoot $SITE_JSON), $json,
        (New-Object System.Text.UTF8Encoding $false))
    Say "Wrote $SITE_JSON"
}

# --------------------------------------------------------------------- verify

Say "Checking the site responds"
try {
    Invoke-WebRequest -Uri $WP_URL -TimeoutSec 10 -UseBasicParsing | Out-Null
    Say "Site is up"
} catch {
    Warn "$WP_URL did not respond."
    Warn "Port already in use? Change WP_PORT in .env and re-run."
    Warn "Using a .loc domain? Check Traefik: docker ps --filter name=traefik"
}

Write-Host ""
Say "Done"
Write-Host "    Site:       $WP_URL"
Write-Host "    Admin:      $WP_URL/wp-admin  ($ADMIN_USER / $ADMIN_PASS)"
Write-Host "    phpMyAdmin: http://localhost:$PMA_PORT"
Write-Host "    Push credentials are in $SITE_JSON (gitignored)"
