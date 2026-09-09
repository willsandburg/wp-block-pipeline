<#
    Connect this project to a live WordPress site. Windows PowerShell.

    Creates the site/ folder structure, verifies the credentials, reads the
    global styles ID and theme off the live site, and writes
    site/site.live.json.

    Nothing is pushed and nothing on the live site is modified. This only reads.

    Usage:
        .\connect.ps1
        .\connect.ps1 -SiteUrl https://example.com -WpUser admin

    If PowerShell refuses to run it:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

param(
    [string]$SiteUrl = '',
    [string]$WpUser  = ''
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Say  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "  ! $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

# ------------------------------------------------------------------- gather

if (-not $SiteUrl) { $SiteUrl = Read-Host "Site URL (e.g. https://example.com)" }
if (-not $WpUser)  { $WpUser  = Read-Host "WordPress username" }

Write-Host "Application password (from Users > Profile > Application Passwords)."
Write-Host "Paste it including the spaces. It will not be echoed."
$secure = Read-Host "> " -AsSecureString
$AppPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

if (-not $SiteUrl)     { Die "No site URL given." }
if (-not $WpUser)      { Die "No username given." }
if (-not $AppPassword) { Die "No application password given." }

$SiteUrl = $SiteUrl.TrimEnd('/')

if ($SiteUrl -like 'http://*') {
    Warn "That URL is http, not https."
    Warn "WordPress disables Application Passwords without SSL, so this will fail."
    Warn "Turn on SSL first, then re-run."
} elseif ($SiteUrl -notlike 'https://*') {
    Die "URL must start with https:// (or http:// for a local site)."
}

# Basic auth header. -Credential does not work reliably here because WordPress
# needs the header sent on the first request, not after a 401 challenge.
$pair    = "$WpUser`:$AppPassword"
$b64     = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
$headers = @{ Authorization = "Basic $b64" }
$OutFile = 'site/site.live.json'

# ------------------------------------------------------------------ folders

Say "Creating folders"
New-Item -ItemType Directory -Force -Path site/pages, site/media | Out-Null
Write-Host "    site/pages/   generated page markup goes here"
Write-Host "    site/media/   images to upload go here"

# --------------------------------------------------------------------- auth

Say "Checking credentials against $SiteUrl"

try {
    $themes = Invoke-RestMethod -Uri "$SiteUrl/wp-json/wp/v2/themes?status=active" `
        -Headers $headers -TimeoutSec 20
    Say "Credentials accepted"
}
catch {
    $code = $_.Exception.Response.StatusCode.value__
    switch ($code) {
        401 { Die "401 Unauthorized. The username or application password is wrong.`n       Check the username is the WP login (not the email), and that the`n       password was pasted whole, spaces included." }
        403 { Die "403 Forbidden. Something is blocking the REST API — often a`n       security plugin or the host's firewall. On SiteGround this is`n       usually mod_security and needs a support ticket." }
        404 { Die "404 Not Found. The REST API is not reachable at that URL.`n       Check the address, and check permalinks are not set to Plain." }
        default { Die "Could not reach $SiteUrl. $($_.Exception.Message)" }
    }
}

# ------------------------------------------------------------ theme + styles

$theme = if ($themes -is [array]) { $themes[0].stylesheet } else { $themes.stylesheet }
if (-not $theme) { $theme = 'unknown' }
Say "Active theme: $theme"

if ($theme -ne 'twentytwentyfive') {
    Warn "Expected twentytwentyfive. The pipeline's markup and styles are written"
    Warn "against it. Activate it in Appearance > Themes, or update WP_THEME."
}

$themeObj = if ($themes -is [array]) { $themes[0] } else { $themes }
$gsLink = $themeObj._links.'https://api.w.org/user-global-styles'.href
$globalStylesId = 'null'

if ($gsLink -match 'global-styles/(\d+)') {
    $candidate = $Matches[1]
    try {
        Invoke-RestMethod -Uri "$SiteUrl/wp-json/wp/v2/global-styles/$candidate" `
            -Headers $headers -TimeoutSec 20 | Out-Null
        $globalStylesId = $candidate
        Say "Global styles ID: $globalStylesId"
    } catch {
        Warn "Global styles ID $candidate is linked but not readable."
        Warn "Save once in the Site Editor, then re-run."
    }
} else {
    Warn "No global styles record found."
    Warn "Open $SiteUrl/wp-admin/site-editor.php, go to Styles, change anything,"
    Warn "save, then run this script again."
}

# ------------------------------------------------------------------ version

# Not exposed over REST. Read the generator meta tag, which some security
# plugins strip — "unknown" is fine, it is only recorded for reference.
$wpVersion = 'unknown'
try {
    $html = (Invoke-WebRequest -Uri "$SiteUrl/" -TimeoutSec 15 -UseBasicParsing).Content
    if ($html -match 'content="WordPress ([0-9.]+)"') { $wpVersion = $Matches[1] }
} catch { }
Say "WordPress version: $wpVersion"

if ($wpVersion -ne 'unknown' -and (Test-Path docker-compose.yml)) {
    $composeText = Get-Content docker-compose.yml -Raw
    if ($composeText -match 'wordpress:([0-9.]+)-php') {
        $pinned = $Matches[1]
        if (-not $wpVersion.StartsWith($pinned)) {
            Warn "Live site is $wpVersion but docker-compose.yml pins $pinned."
            Warn "Your block markup was verified against $pinned. Match them, or"
            Warn "re-run the verification pass in allowed-blocks.md."
        }
    }
}

# --------------------------------------------------------------- write file

if (Test-Path $OutFile) {
    Warn "$OutFile already exists."
    Warn "It holds the page and media ID maps. Overwriting orphans everything"
    Warn "already pushed, and the next push will create duplicates."
    $confirm = Read-Host "Overwrite anyway? (type yes to confirm)"
    if ($confirm -ne 'yes') { Say "Left alone. Nothing changed."; exit 0 }
    Copy-Item $OutFile "$OutFile.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Say "Backed up the old one first"
}

$json = @"
{
  "url": "$SiteUrl",
  "user": "$WpUser",
  "app_password": "$AppPassword",
  "global_styles_id": $globalStylesId,
  "theme": "$theme",
  "wp_version": "$wpVersion",
  "pages": {},
  "media": {}
}
"@

# No BOM. PowerShell's default UTF8 encoding adds one and breaks JSON parsers.
[System.IO.File]::WriteAllText(
    (Join-Path $PSScriptRoot $OutFile), $json,
    (New-Object System.Text.UTF8Encoding $false))
Say "Wrote $OutFile"

# ---------------------------------------------------------------- gitignore

if (-not (Test-Path .gitignore)) { New-Item -ItemType File .gitignore | Out-Null }
$existing = Get-Content .gitignore -ErrorAction SilentlyContinue
foreach ($line in @('site/site.json', 'site/site.live.json', 'site/site.*.json.backup.*')) {
    if ($existing -notcontains $line) { Add-Content .gitignore $line }
}
Say "Credentials excluded from git"

Write-Host ""
Say "Connected"
Write-Host "    Site:   $SiteUrl"
Write-Host "    Config: $OutFile"
Write-Host ""
if ($globalStylesId -eq 'null') {
    Write-Host "    Save once in the Site Editor and re-run before pushing styles."
} else {
    Write-Host "    Ready to push. Styles first, then media, then pages."
}
