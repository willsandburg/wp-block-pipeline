# The WordPress block pipeline

The complete procedure for a WordPress site built by generating blocks and
global styles and pushing them to a running install over the REST API.

Read this only after Step 1 of [../SKILL.md](../SKILL.md) has established the
domain and what the site is for.

**This is not the classic-theme WordPress path.** That path downloads WordPress
to disk, builds a theme with `header.php` and `index.php`, and deploys over
SFTP. This one runs WordPress from a Docker image, uses the bundled block theme,
and pushes content over HTTP. They produce different sites and are not
interchangeable. If the client needs custom PHP templates, use the other path.

Before writing any markup, read:

- [allowed-blocks.md](allowed-blocks.md) — the only blocks permitted, and the
  rule for what happens when something is missing
- [global-styles.md](global-styles.md) — the shape of the styles object
- [wp-design.md](wp-design.md) — what separates a generated site from a good one

---

## The stack

Fixed. Do not substitute without changing this file.

| | |
| --- | --- |
| WordPress | 7.1, pinned, from the official Docker image |
| Theme | Twenty Twenty-Five, bundled with core, activated by name |
| Editor | Gutenberg, built into core |
| Blocks | core only, restricted to the approved list |
| Design | global styles written to the database |
| Forms | the receiver plugin's form block |
| Local | Docker + Traefik, `.loc` domain |

Two things are pinned on purpose. **The WordPress version**, because block save
output changes between releases and your validated markup is only valid against
one of them. **The theme, by name**, because Twenty Twenty-Seven is due with
WordPress 7.2 in December 2026 and will become the default on new installs — a
pipeline that activates "the default theme" will silently start rendering
against a different `theme.json`.

---

## Step 1 — Derive names and create the folder

Slug from the domain: lowercase, strip the TLD, replace hyphens and dots with
underscores. `example.com` → `example`, `my-site.com` → `my_site`.

```
{slug}/
├── docker-compose.yml
├── bootstrap.sh
├── .env
├── .gitignore
├── CLAUDE.md
├── README.md
├── plugin/                  ← receiver plugin, bind-mounted into the container
├── docker/
│   └── mysql-data/          ← gitignored
├── resources/
│   ├── design/              ← brand kit, mockups. Never deployed
│   └── docs/
│       └── traefik-setup.md
└── site/
    ├── site.json            ← URL, credentials, page map
    ├── styles.json          ← generated global styles
    ├── media/               ← source images, pushed to the media library
    └── pages/
        ├── home.html
        └── about.html
```

`site/` is the source of truth for content. Everything in it is generated, and
everything in it is pushed. Nothing outside it is.

---

## Step 2 — Where does this site run?

Ask before installing anything. Three options, in order of preference:

| | Needs | Use when |
| --- | --- | --- |
| **A site you already have** | nothing | Default. A live site or host staging copy. |
| **Playground** | Node 20.18+ | Offline work, or no host yet. |
| **Docker** | Docker Desktop | You specifically want MySQL and Apache locally. |

**Prefer a site they already have.** Most hosts have one-click staging, it
installs nothing, and it matches the stack the client ends up on — which is the
only environment whose block validation actually matters.

Then jump to the right section:

- Existing site → skip to "Connecting to a live site" at the end of this file
- Playground → Step 2b
- Docker → Step 2a

---

## Step 2a — Docker: check Docker and Traefik

```bash
docker info > /dev/null 2>&1
```

If Docker is not available, create the files anyway and tell the user the site
cannot run locally until Docker Desktop is installed.

```bash
docker ps --filter "name=traefik" --format "{{.Names}}"
```

If Traefik is not running, tell the user to follow
`resources/docs/traefik-setup.md` first. That setup is unchanged from the other
stacks — same dnsmasq, same `.loc` wildcard, same shared network.

---

## Step 2b — Playground

The official replacement for the deprecated wp-now. No Docker, MySQL, or
Apache; Node 20.18 or newer is the only requirement.

Copy `playground.sh`, `playground-connect.sh` and `blueprint.json` into the
project root. Nothing else — no compose files, no `.env`, no bootstrap.

Run `pwd`, then give the person both lines with the absolute path:

> Run these and leave the window open:
> ```
> cd /absolute/path/from/pwd
> ./playground.sh
> ```

It runs in the foreground and Ctrl+C stops it, so it needs its own terminal.
The site persists between runs.

When they confirm it is up, run `./playground-connect.sh` yourself. It verifies
REST, creates an application password, reads the global styles ID, and writes
`site/site.json`.

**`blueprint.json` sets `WP_ENVIRONMENT_TYPE=local`.** That is what allows
application passwords over plain http — WordPress refuses to issue them
otherwise. It also pins the WordPress version and activates the theme. Do not
remove either.

**Playground uses SQLite rather than MySQL.** Irrelevant here: block markup and
global styles are PHP and JS concerns. If something genuinely depends on MySQL,
use Docker.

Then continue from Step 5.

---

## Step 3 — Write the Docker files

Copy `docker-compose.yml` and `bootstrap.sh` from
[assets/](assets/), substituting `{slug}` throughout.

The critical difference from the classic-theme path: **do not bind-mount a
docroot over `/var/www/html`.** WordPress core comes from the image. A named
volume holds it, and only the plugin folder is bind-mounted:

```yaml
volumes:
  - wp_core:/var/www/html
  - ./plugin:/var/www/html/wp-content/plugins/{slug}-receiver
```

Mounting a host folder over the whole docroot is correct when the site's files
already exist on disk. Here they do not, and doing it produces an empty site.

`.env` — **write this as `env.staged.txt`, not as `.env`.**

Many people have a settings rule denying agent access to `.env` files, and it
is a good rule worth keeping: real `.env` files hold API keys and passwords.
Attempting `.env` first to see whether it is allowed just produces a permission
prompt on every new project.

So always write `env.staged.txt`. Then run `pwd`, and give the person **both
lines with the absolute path filled in**:

> Run these two lines in a terminal, then tell me when it's done:
> ```
> cd /absolute/path/from/pwd
> cp env.staged.txt .env
> ```

Never say "run this in the project root" without the path. The person is
usually in a different terminal tab sitting in their home directory, and a bare
`cp` fails with "No such file or directory" — which reads like the file was
never created.

**This rule covers every terminal instruction in this file.** Always `pwd`
first and prefix with `cd`.

Wait for confirmation before continuing. Never suggest they change their
permission settings.

```
DB_DATABASE={slug}
DB_USERNAME={slug}
DB_PASSWORD=
DB_ROOT_PASSWORD=
DB_HOST=db
DB_PORT=3306

WP_URL=http://{slug}.loc
WP_TITLE={Site name}
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin
WP_ADMIN_EMAIL=admin@{domain}
```

Local passwords are intentionally trivial. Nothing in this file reaches
production.

`.gitignore`:

```
.env
docker/mysql-data/
resources/design/
site/site.json
```

`site.json` holds an application password. It is gitignored, and it is
regenerated by bootstrap rather than shared.

---

## Step 4 — Bring the site up

Confirm `.env` exists before running bootstrap — it reads from it and will
exit with a clear error if it is missing.

```bash
docker compose up -d
./bootstrap.sh
```

Bootstrap is not optional and is not a convenience. It does the work that would
otherwise be manual clicking, and it produces `site.json`, which everything
downstream reads:

1. Waits for MySQL to accept connections
2. `wp core install` — no five-minute wizard
3. Deletes the sample page and the Hello World post
4. Activates `twentytwentyfive` by name
5. Activates the receiver plugin if `plugin/` contains one
6. Sets permalinks to `/%postname%/`
7. Creates an application password for REST access
8. Reads the global styles post ID
9. Writes all of it to `site/site.json`

Confirm `http://{slug}.loc` serves before continuing. If Traefik is not
running, it will not.

`site.json` after bootstrap:

```json
{
  "url": "http://example.loc",
  "user": "admin",
  "app_password": "xxxx xxxx xxxx xxxx xxxx xxxx",
  "global_styles_id": 12,
  "theme": "twentytwentyfive",
  "wp_version": "7.0",
  "pages": {},
  "media": {}
}
```

`pages` maps a local filename to the page ID WordPress assigned it. `media`
maps a local filename to its attachment ID. **Both are the reason re-pushing
updates a page instead of creating a second copy of it.** Never regenerate
`site.json` from scratch on an existing site — that orphans every page and
image already there.

---

## Step 5 — Interview for design direction

Before generating anything, establish:

1. **The one thing a visitor should remember.** Not a feature list. One thing.
   If this cannot be answered, the site will be generic, and no amount of
   styling fixes that.
2. **Brand assets.** Logo, colours, fonts, existing materials. Ask, and ask
   the user to drop them in `resources/design/`. Having them makes every later
   decision better.
3. **Page list.** Which pages, and what each is for.
4. **Editing posture.** Which sections the client may restructure and which are
   locked. Default is structural sections locked `contentOnly`, body content
   open.

Record all four in `CLAUDE.md`.

---

## Step 6 — Generate global styles

Write `site/styles.json` following [global-styles.md](global-styles.md).

This is the highest-leverage step in the whole procedure. Palette, type scale,
spacing scale and per-block defaults live here, and every block on the site
inherits from them. A well-built styles object makes plain core blocks look
designed. A weak one makes them look like a default WordPress install with
different colours.

Do this **before** generating any page. Pages reference preset slugs, so the
presets have to exist first.

Push it:

```bash
curl -X POST "$WP_URL/wp-json/wp/v2/global-styles/$GLOBAL_STYLES_ID" \
  -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d @site/styles.json
```

Then publish the style specimen before building anything else.

---

## Step 6b — The style specimen

**Every site, every time.** Copy `style-specimen.html` and `specimen.py` from
[assets/](assets/) into the project root:

```bash
python3 specimen.py site/site.json
```

One page carrying every style on the site — h1 to h6, body copy at each size,
both button styles, links, lists, a quote, a table, an FAQ, the six palette
swatches, a grid, unequal columns, the spacing scale, and full-bleed accent and
dark panels. Stop and let the person look at it before any real page exists.

An empty site tells you nothing, and a design system judged one page at a time
gets judged after four pages already depend on it.

It is deliberately built to expose the failures that otherwise survive to a
finished page: a filled button on the dark panel that matches the panel and
stops reading as a button, secondary text that fails contrast on the surface it
actually sits on, a grid row that goes ragged because `minimumColumnWidth` does
not divide the wide width cleanly, and a heading that wraps past three lines at
375px. Every one of those is a design-system fix, not a page fix.

After media exists, append the image section and re-push so Image, Cover and
Media & Text are judged too:

```bash
python3 specimen.py site/site.json --with-media photo.jpg hero.jpg
```

The page ID is recorded under `specimen_page`, **not** under `pages`. Anything
in `pages` is site content and `deploy.py` pushes it to the live site; the
specimen must never ship. Remove it before handover:

```bash
python3 specimen.py site/site.json --remove
```

---

## Step 6c — Put the brand assets in the project

Once the styles are accepted, copy the brand source files into
`resources/design/` — brand guide, palette, logo exports, fonts, photography —
and write `resources/design/SOURCES.md` recording where each came from and what
it is authoritative for.

Leaving them scattered across the machine means the next session cannot find
them, and asking the person again where their logo lives makes the tool look
like it has no memory. Keep the original paths in `SOURCES.md`: copies go stale
and that file is how anyone finds the current version.

`resources/design/` is gitignored except for `SOURCES.md`. Client photography
and licensed fonts do not belong in a repository; the record of where they live
does, and it survives a clone.

Record in `CLAUDE.md` the brand rules that bind the build — exact spelling of
the name, trademarks the guide says to avoid, what may and may not be claimed
about the work being shown, colour pairings the guide forbids. **Raise conflicts
between a brand rule and an instruction before building, not after.**

---

## Step 7 — Push media

**Media goes first, always.** Image and Cover blocks embed the attachment ID in
their markup, so the attachment has to exist before the page that references it.

For each file in `site/media/`:

```bash
curl -X POST "$WP_URL/wp-json/wp/v2/media" \
  -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Disposition: attachment; filename=hero.jpg" \
  -H "Content-Type: image/jpeg" \
  --data-binary @site/media/hero.jpg
```

The response contains `id` and `source_url`. Record both in `site.json` under
`media`, keyed by filename. Set alt text in a follow-up call:

```bash
curl -X POST "$WP_URL/wp-json/wp/v2/media/$ID" \
  -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"alt_text":"Descriptive alt text"}'
```

Skip files already listed in `site.json` unless the source has changed. Every
push should be idempotent.

---

## Step 8 — Generate pages

One HTML file per page in `site/pages/`, containing serialized block markup and
nothing else. No `<html>`, no `<head>`, no wrapper — the file's entire contents
become the page's `content` field.

Rules, all of which come from [allowed-blocks.md](allowed-blocks.md):

- Approved blocks only. Compose before refusing. Never `core/html`.
- Spacing and colour from preset variables, in both syntaxes, agreeing.
- Every top-level section named with `metadata.name`.
- Locking applied per the Step 5 decision.
- Image and Cover blocks use real attachment IDs from `site.json`.

Push each page:

```bash
curl -X POST "$WP_URL/wp-json/wp/v2/pages" \
  -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "About" --arg s "about" --rawfile c site/pages/about.html \
    '{title:$t, slug:$s, status:"publish", content:$c}')"
```

If the page already has an ID in `site.json`, POST to
`/wp-json/wp/v2/pages/{id}` instead. Same endpoint, updates rather than
creates. Record new IDs in `site.json` immediately — a page created without its
ID recorded will be duplicated on the next push.

Set the front page once, after home exists:

```bash
docker compose run --rm wpcli option update show_on_front page
docker compose run --rm wpcli option update page_on_front $HOME_PAGE_ID
```

---

## Step 8b — Use `page-no-title` for any page with its own hero

Twenty Twenty-Five's default `page` template renders `post-title` as an `h1`. A
page whose content opens with its own hero heading therefore ships **two `h1`
elements** — an accessibility fault, and one this pipeline's own design rules
forbid.

The theme already ships the fix. Set the page's `template` field when pushing:

```json
{"title":"Home","slug":"home","status":"publish","template":"page-no-title"}
```

That also drops the `spacing|60` margin and padding the default template puts
above the content, which is what leaves a large gap over a full-bleed hero.

---

## Step 9 — Verify

A page that pushed successfully is not a page that works. Check all four:

1. **Open the page in the editor.** Any block showing "Attempt Block Recovery"
   means the markup failed validation. Fix the markup in `allowed-blocks.md`,
   not the page — every future site inherits the error.
2. **Check the locking.** Log in as a non-admin, or read the page as the client
   would. Can they edit the text? Can they break the layout?
3. **Check it at 375px, 768px and 1440px.** Not just the desktop width.
4. **Check contrast.** Body text at 4.5:1 against what is actually behind it,
   which for a Cover block means against the image plus the overlay, not
   against the overlay colour alone.

Only after all four pass is the site ready to hand over.

---

## Step 10 — Write the project CLAUDE.md

```markdown
# CLAUDE.md — {domain}

## Project
{What the business is, who it serves, the one action a visitor should take.}
{The one thing a visitor should remember.}

Stack: WordPress {version} · Twenty Twenty-Five · core blocks · generated global styles
Local: `docker compose up -d` → http://{slug}.loc
Admin: http://{slug}.loc/wp-admin

## How this site is built
Content is generated into `site/` and pushed over REST. **The site is not
edited by hand and the database is not the source of truth for structure.**
Change `site/pages/*.html` and push again.

Client edits made in the WordPress editor WILL be overwritten by the next push.
Before pushing to a live site the client has touched, pull current state first.

## Rules
- Read `references/allowed-blocks.md` before writing any markup. Approved
  blocks only. Never `core/html`, never `core/shortcode`, never inline styles
  that are not preset variables.
- Read `references/wp-design.md` before any layout work.
- Media pushes before pages. Always.
- Record every new page and attachment ID in `site.json` immediately.
- Never regenerate `site.json` on a site that already has content.
- The theme is activated by name. Do not switch to "the default theme".

## Editing posture
{Which sections are locked contentOnly, which are open.}

## Before launch
- [ ] Every page opens in the editor with no block recovery prompts
- [ ] Checked at 375px, 768px, 1440px
- [ ] Body text hits 4.5:1 against its actual background
- [ ] Every image has alt text
- [ ] Site title, tagline and favicon set
- [ ] Contact form tested end to end
```

---

## Step 11 — Report

Tell the user:

- What was created and where
- `docker compose up -d` then `./bootstrap.sh` to bring the site up
- `http://{slug}.loc` and `/wp-admin`, with the admin credentials from `.env`
- That `site/` is the source of truth and hand-editing in WordPress will be
  overwritten on the next push
- That `resources/design/` is where a brand kit goes, and that adding one
  improves every later decision
- Anything still missing: real copy, real images, favicon, form recipient

---

## Connecting to a live site

Run `connect.sh` (or `connect.ps1` on Windows PowerShell). It creates the
`site/` folders, verifies the credentials, reads the theme and global styles ID
off the live site, writes `site/site.live.json`, and adds the credentials to
`.gitignore`.

```bash
./connect.sh                              # prompts for everything
./connect.sh https://example.com admin    # prompts for the password only
```

It only reads. Nothing is pushed and nothing on the live site changes.

Before running it, on the live site:

1. WordPress installed at the domain root
2. **SSL on, and HTTPS forced.** WordPress hides Application Passwords entirely
   without it, so the credential this needs will not exist
3. Twenty Twenty-Five activated
4. Permalinks set to anything other than Plain, or the REST API is unreachable
5. An application password created under Users → Profile → Application Passwords
6. ~~The Site Editor opened once and saved~~ — **this appears not to be required
   on WordPress 7.1.** A Playground site built from `blueprint.json` had a global
   styles record before the Site Editor was ever opened, and so did a live 7.1
   install. The belief that it was missing traced to a grep bug in `connect.sh`
   that could never match the ID. If a target genuinely reports no record, open
   the Site Editor, change any style and save — but do not ask for it up front.

The script checks 2 through 6 and tells you which one failed rather than
returning a generic error.

### After connecting

Push with `assets/deploy.py site/site.live.json`. The order is the same — styles,
then media, then pages — but **the page files are not transferable as they
stand.**

Page markup embeds attachment IDs (`"id":8`, `wp-image-8`, `"mediaId":9`) and
absolute upload URLs, and those belong to the site they were generated against.
Push the same files to a second site unchanged and every image breaks and every
Cover fails validation.

`deploy.py` uploads the media to the target first, records the target's own IDs,
then rewrites every ID, upload URL and internal page link before the pages go up.
It swaps in two passes through placeholders, because a local ID can collide with
a live one — local 8 becoming live 12 while local 12 also exists — and a naive
sequential replace corrupts it.

Internal links need the same treatment. A button pointing at
`http://127.0.0.1:9400/output/` survives the media swap untouched and ships a
link to your laptop.

Run it with `--dry` first. That prints exactly what would be uploaded and created
without touching the target.

If the host caches (SG Optimizer, a CDN), purge after every push or you will
see stale pages and think the push failed.

### Two rules for live sites

**Push to local first, always.** The Docker environment exists so mistakes
happen there instead of on a site a client is looking at.

**Never delete `site.live.json` once it has content in `pages` or `media`.**
Those IDs are the only record of what is already on the site. Lose them and the
next push builds a second copy of everything. The script backs the file up
before overwriting and asks for confirmation, but the safe move is to leave it
alone.
