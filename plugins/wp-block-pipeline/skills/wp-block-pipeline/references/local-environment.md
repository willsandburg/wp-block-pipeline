# Local environment

You may not need one. Read this first.

## Do you need a local site at all?

**Probably not.** If the client already has hosting, use a staging site. Most
hosts have one-click staging, it installs nothing on your machine, and it runs
the same WordPress version, PHP version and server stack the site ships on —
which is the only environment where block validation actually tells you
anything.

A local site is worth setting up when you want to work offline, when there is
no host yet, or when you want to break things without anyone seeing.

## If you do want one, two options

**Playground** — one command, Node 20.18 or newer, nothing else:

```
./playground.sh
```

No Docker, no MySQL, no Apache. Starts in seconds, persists between runs, and
`blueprint.json` pins the WordPress version. It uses SQLite instead of MySQL,
which does not matter for block markup or global styles.

**Docker** — the full MySQL and Apache stack. Matches production more closely,
costs a multi-gigabyte install and a daemon you have to remember to start.
Worth it if you are testing something database-specific or you already run
Docker anyway.

The rest of this file covers the Docker path.

---

## Docker: two modes

**Port mode** is the default and needs nothing but Docker. **Domain mode**
gives every project a clean `.loc` address with no port number, at the cost of
a one-time setup that differs per operating system.

Start in port mode. Move to domain mode only if you run several projects at
once and the ports become annoying.

---

## Requirements

| | |
| --- | --- |
| macOS | Docker Desktop |
| Windows | Docker Desktop, with WSL 2 backend |
| Linux | Docker Engine and the Compose plugin |

Nothing else. No Homebrew, no PHP, no MySQL, no local WordPress.

Check it is working:

```
docker info
docker compose version
```

---

## Port mode (default)

`.env`:

```
WP_PORT=8080
PMA_PORT=8081
WP_URL=http://localhost:8080
```

Then:

```
docker compose up -d
```

```bash
./bootstrap.sh          # macOS, Linux, WSL, Git Bash
```
```powershell
.\bootstrap.ps1         # Windows PowerShell
```

Site at `http://localhost:8080`, phpMyAdmin at `http://localhost:8081`.

**Running more than one project?** Give each one different ports. 8080/8081,
8082/8083, and so on. If a port is taken, the containers start but the site
does not answer — change `WP_PORT` and re-run.

**`WP_URL` must match the port.** WordPress stores its own address, and a
mismatch produces redirect loops that look like a broken site.

---

## Domain mode (optional)

Gives you `http://clientname.loc` instead of `http://localhost:8082`, with no
port juggling across projects. Worth setting up if you run several sites at
once. Skip it otherwise.

Three pieces: a wildcard DNS rule so `*.loc` resolves to localhost, a shared
Docker network, and one Traefik container that routes by hostname.

### Step 1 — Wildcard DNS

**macOS**

```bash
brew install dnsmasq
echo 'address=/.loc/127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf
sudo brew services start dnsmasq
sudo mkdir -p /etc/resolver
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/loc
```

`$(brew --prefix)` covers both Apple Silicon (`/opt/homebrew`) and Intel
(`/usr/local`). Verify with `ping -c 1 anything.loc`.

**Linux (systemd-resolved, which is most distributions)**

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNS=127.0.0.1\nDomains=~loc\n' | sudo tee /etc/systemd/resolved.conf.d/loc.conf
sudo apt install dnsmasq          # or your package manager's equivalent
echo 'address=/.loc/127.0.0.1' | sudo tee /etc/dnsmasq.d/loc.conf
sudo systemctl restart dnsmasq systemd-resolved
```

If dnsmasq will not start because port 53 is taken, systemd-resolved is already
listening on it. Set `DNSStubListener=no` in `/etc/systemd/resolved.conf` and
restart both.

**Windows**

Windows has no clean wildcard DNS equivalent. Add one line to the hosts file
per project instead.

Open Notepad as Administrator, then open
`C:\Windows\System32\drivers\etc\hosts` and add:

```
127.0.0.1  clientname.loc pma.clientname.loc
```

Repeat per project. It is more manual than the other two platforms, which is
part of why port mode is the default.

Alternatively, run everything inside WSL and follow the Linux instructions
there. That is the smoother path if you already work in WSL.

### Step 2 — Shared network

```
docker network create traefik_network
```

Once per machine.

### Step 3 — Traefik

Create a folder outside any project — `~/traefik`, or `C:\traefik` on Windows —
with this `docker-compose.yml`:

```yaml
services:
  traefik:
    image: traefik:v2.11
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.network=traefik_network"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "9090:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - traefik_network
    restart: unless-stopped

networks:
  traefik_network:
    external: true
```

Then `docker compose up -d`. Dashboard at `http://localhost:9090`.

Two things learned the hard way, both still true:

- **Use `traefik:v2.11`.** v3.0 has a Docker provider incompatibility with
  Docker Desktop.
- **`--providers.docker.network` is required.** Without it, Traefik picks the
  wrong container IP when a container sits on two networks, and you get
  Gateway Timeouts that look like the site is down.

The socket mount path is the same on all three platforms. On Windows, Docker
Desktop exposes it inside the Linux VM, so the Unix path is correct even though
it looks wrong.

### Step 4 — Switch a project to domain mode

In `.env`:

```
WP_URL=http://clientname.loc
SITE_HOST=clientname.loc
COMPOSE_PROJECT_NAME=clientname
COMPOSE_FILE=docker-compose.yml:docker-compose.traefik.yml
```

**On Windows the `COMPOSE_FILE` separator is a semicolon, not a colon.**

Then `docker compose up -d` picks up both files. The override removes the
published ports and adds Traefik labels, so nothing collides.

Traefik runs with `restart: unless-stopped`, so it comes back with Docker and
you should not need to touch it again.

---

## Everyday commands

```
docker compose up -d              # start
docker compose down               # stop, keeps data
docker compose down -v            # stop and DELETE the database and WordPress
docker compose logs -f web        # tail the web server
docker compose run --rm wpcli plugin list
```

`down -v` removes the named volumes. That is a full reset — every page, image
and setting is gone. `site/` survives, so a re-run of bootstrap plus a re-push
rebuilds the site. That is the intended recovery path, and it is a good reason
to keep `site/` as the real source of truth.

---

## Platform notes

**Line endings.** The shell script breaks if Git converts it to CRLF. A
`.gitattributes` at the project root prevents it:

```
*.sh text eol=lf
*.ps1 text eol=crlf
```

If you get `bad interpreter: /usr/bin/env^M`, this is why.

**Executable bit on Windows.** Git checkouts on Windows do not preserve it. Run
`bash bootstrap.sh` rather than `./bootstrap.sh`, or use the PowerShell version.

**PowerShell execution policy.** If `.\bootstrap.ps1` is blocked:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Scoped to the session, so it reverts when the window closes.

**File watching on Windows and macOS.** Only `plugin/` is bind-mounted, which
keeps things fast. Do not bind-mount the whole WordPress directory to "make
editing easier" — it will crawl, and it defeats the volume strategy the compose
file depends on.

**Linux file ownership.** The `wpcli` service runs as `33:33` to match the
`www-data` user inside the containers. If you hit permission errors writing to
`plugin/`, `chown -R 33:33 plugin` or add your user to a matching group.

---

## When something does not work

**Site does not respond in port mode.** Port is taken. Change `WP_PORT` and
`WP_URL` together, then re-run bootstrap.

**Redirect loop, or the site sends you to the wrong address.** `WP_URL` does
not match how you are reaching the site. Fix it, then:

```
docker compose run --rm wpcli option update home "http://localhost:8080"
docker compose run --rm wpcli option update siteurl "http://localhost:8080"
```

**Gateway Timeout in domain mode.** Traefik is on the wrong network. Confirm
`--providers.docker.network=traefik_network` is in the Traefik command.

**`.loc` does not resolve.** DNS step did not take. macOS and Linux: `ping -c 1
anything.loc` should hit 127.0.0.1. Windows: check the hosts file entry.

**Database will not start, or bootstrap times out waiting for it.** Two
causes, both fixed the same way.

Empty `DB_PASSWORD` or `DB_ROOT_PASSWORD` in `.env`. Both must be non-empty:
an empty password makes the database entrypoint skip creating the application
user, logging only a `[Warn]`, and everything downstream then fails as though
the database were unreachable.

Or a stale volume from an earlier run with different credentials. Database
credentials are only applied on first initialisation, so changing `.env`
afterwards has no effect until the volume is recreated.

```
docker compose down -v
docker compose up -d
./bootstrap.sh
```

`-v` deletes the local database and WordPress install. Nothing of value lives
there — `site/` is the source of truth, so re-running bootstrap and re-pushing
rebuilds everything.

**wp-cli fails with `ERROR 1156: Plugin caching_sha2_password could not be
loaded` or `ERROR 2026: TLS/SSL error`.** The compose file is running MySQL 8
rather than MariaDB. The MariaDB client shipped in `wordpress:cli` cannot load
MySQL 8's default auth plugin, and it rejects MySQL 8's auto-generated
self-signed certificate. Use `mariadb:11` as shipped. If you switched the image
deliberately, you will need `--skip-ssl` and a `mysql_native_password` user.
