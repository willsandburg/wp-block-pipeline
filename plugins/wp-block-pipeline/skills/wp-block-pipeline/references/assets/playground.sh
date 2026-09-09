#!/usr/bin/env bash
#
# Start a local WordPress with the Playground CLI. No Docker, no MySQL.
#
# Needs Node 20.18 or newer and nothing else. The site persists between runs.
#
# Designed to be run in the BACKGROUND by an agent — it writes a log file and
# a pid file, and exits once the site is answering. A person can also run it
# directly; it behaves the same either way.
#
# Usage:
#   ./playground.sh                start (or restart) the site
#   ./playground.sh --port 9400    use a specific port
#   ./playground.sh --stop         stop a running site
#   ./playground.sh --status       is it up?

set -euo pipefail
cd "$(dirname "$0")"

LOG=".playground.log"
PIDFILE=".playground.pid"
PORT=9400
ACTION=start

while [ $# -gt 0 ]; do
  case "$1" in
    --port)   PORT="$2"; shift 2 ;;
    --stop)   ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

say()  { printf '==> %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "$ACTION" in
  stop)
    if running; then
      kill "$(cat "$PIDFILE")" 2>/dev/null || true
      sleep 1
      rm -f "$PIDFILE"
      say "Stopped. The site persists — run this again to bring it back."
    else
      say "Not running."
      rm -f "$PIDFILE"
    fi
    exit 0 ;;
  status)
    if running; then say "Running (pid $(cat "$PIDFILE"))"; exit 0
    else say "Not running"; exit 1; fi ;;
esac

# ------------------------------------------------------------------- checks

if running; then
  say "Already running (pid $(cat "$PIDFILE")). Nothing to do."
  exit 0
fi

command -v node >/dev/null 2>&1 || die "Node.js is not installed.
       Playground needs Node 20.18 or newer: https://nodejs.org
       Or use the Docker path instead — see local-environment.md."

NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
NODE_MINOR="$(node -v | sed 's/^v//' | cut -d. -f2)"
if [ "$NODE_MAJOR" -lt 20 ] || { [ "$NODE_MAJOR" -eq 20 ] && [ "$NODE_MINOR" -lt 18 ]; }; then
  die "Node $(node -v) is too old. Playground CLI needs 20.18 or newer."
fi
say "Node $(node -v)"

[ -f blueprint.json ] || die "blueprint.json is missing. It pins the WordPress
       version, activates the theme, and marks the site as a local environment
       so application passwords work over plain http."

mkdir -p site/pages site/media

# Find a free port if the chosen one is taken
while lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
  warn "Port $PORT is in use, trying $((PORT+1))"
  PORT=$((PORT+1))
done

# -------------------------------------------------------------------- start

say "Starting WordPress on port $PORT"
: > "$LOG"

nohup npx --yes @wp-playground/cli@latest start \
  --blueprint=blueprint.json \
  --port="$PORT" \
  --auto-mount \
  --quiet \
  >> "$LOG" 2>&1 &

echo $! > "$PIDFILE"

# Wait for it to actually answer. First run downloads the runtime.
URL="http://127.0.0.1:$PORT"
say "Waiting for the site (first run downloads the runtime, up to 3 minutes)"

for i in $(seq 1 180); do
  if curl -sf -o /dev/null --max-time 3 "$URL" 2>/dev/null; then
    say "Site is up at $URL"
    echo "$PORT" > .playground.port
    echo
    echo "    Site:  $URL"
    echo "    Admin: $URL/wp-admin"
    echo "    Log:   $LOG"
    echo "    Stop:  ./playground.sh --stop"
    exit 0
  fi
  if ! running; then
    echo >&2
    echo "Playground exited before the site came up. Last 30 lines of $LOG:" >&2
    tail -30 "$LOG" >&2
    rm -f "$PIDFILE"
    exit 1
  fi
  sleep 1
done

echo >&2
echo "Timed out after 3 minutes. Last 30 lines of $LOG:" >&2
tail -30 "$LOG" >&2
exit 1
