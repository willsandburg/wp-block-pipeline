---
description: Publish a generated site to a live WordPress install — connects with one click in the browser, checks, then pushes.
argument-hint: "[optional site URL]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebFetch
---

# Publish to a live site

Argument, if given: **$ARGUMENTS**

Never push to a live site without running the checks first. If a phase fails,
stop and report it — do not improvise around a failure on a site the client can
see.

---

## Phase 0 — Load the rules

Read `references/allowed-blocks.md` and `references/wp-design.md`. Same rules as
generation; a push does not relax them.

## Phase 1 — Is anything already there?

If `site/site.live.json` exists and has entries in `pages` or `media`, **this
site has been published before.** Those IDs are the only record of what is on
it. Do not delete or regenerate the file. The push updates by ID; without it you
create a second copy of every page.

If it does not exist, go to Phase 2.

## Phase 2 — Connect, without anyone typing a password

**Do not ask for a password. Do not ask them to put one in a `.env`.** A `.env`
holding a live credential is exactly the file most people's settings deny agents
access to, and it is a good rule.

Ask for the site URL, then run:

```
python3 authorize.py https://theirsite.com
```

That starts a listener on 127.0.0.1, opens WordPress's own authorization screen,
and captures the credential WordPress redirects back with. The person clicks
**Approve** once. The password goes browser → localhost → `site/site.live.json`
(mode 600). It is never typed, pasted, or shown.

Tell them a browser tab is opening and what to click. If it does not open, the
script prints the URL.

**Prerequisites, in the order they bite:**

1. **HTTPS.** WordPress hides Application Passwords entirely without it, so the
   authorize screen will not offer anything to approve.
2. **Logged into wp-admin** in their default browser. If not, WordPress sends
   them to log in and returns them to the screen.
3. **Twenty Twenty-Five active.**
4. **Permalinks not Plain**, or REST is unreachable.

If the flow fails, report which of those it was rather than retrying.

## Phase 3 — Install the site plugin

Check whether the receiver plugin is active:

```
curl -s -u "$USER:$PASS" "$URL/wp-json/wp/v2/block-types/highlandsites/form"
```

A 200 means it is there. A 404 means it is not, and **any page using the form
block will render nothing**.

WordPress refuses remote installation of arbitrary plugin zips — the REST
endpoint accepts only a wordpress.org `slug`. So this step is theirs:

> Go to `{site}/wp-admin/plugin-install.php?tab=upload`, upload
> `plugin/highlandsites.zip`, and activate it.

Copy the zip into the project first so they can find it:
`mkdir -p plugin && cp "${CLAUDE_PLUGIN_ROOT}/receiver/highlandsites.zip" plugin/`

Wait for confirmation before pushing pages. Do not work around it.

## Phase 4 — Check before pushing

```
python3 audit.py site/pages site/site.json site/styles.json
```

Approved blocks only, one `h1` per page, no skipped heading levels, alt text on
every image, no hardcoded px or hex, preset syntaxes agreeing, colour slugs real,
attachment IDs real, and **`dimRatio` carrying its matching level class**. That
last one renders perfectly and fails in the editor, so nothing but a check
catches it.

Non-zero exit means stop and fix. Do not push a page that fails.

## Phase 5 — Dry run, then push

```
python3 deploy.py site/site.live.json --dry
```

The page list, titles, order, site title, logo and icon come from
`site/pages/_pages.json`. If it is missing, write it now from the pages that
exist (see the docstring in `deploy.py`) rather than letting titles be guessed
from filenames. Check the dry run shows this site's name, not another's.

Show them exactly what would be uploaded and created. Then, once they confirm:

```
python3 deploy.py site/site.live.json
```

Order is fixed: styles, then media, then pages, then settings.

**Page markup is not portable between sites.** It embeds attachment IDs and
absolute upload URLs. `deploy.py` uploads media to the target first, then
rewrites every ID, upload URL and internal link to the target's own before the
pages go up. Do not push page files to a second site without that step — the
images break and the Cover blocks fail validation.

## Phase 6 — Template parts and settings

Header and footer are template-level and are not page content, so a page push
does not touch them. On a fresh install, check and fix:

- **Site Logo** in the header — the theme's header has a Site Title and no logo.
- **The footer's demo navigation.** A stock block theme ships links pointing at
  `#`. Shipping those is the same failure as shipping demo content, and the page
  audit does not see template parts.
- **Site title, front page, logo and icon** — `deploy.py` sets these.
- **The theme's Sample Page**, if it is still there.

## Phase 7 — Verify on the live site

Fetch the live pages and confirm, rather than trusting the push returned 200:

- Every page responds
- No reference to the source site remains (`127.0.0.1`, a `.loc` domain, or the
  Playground port)
- Every image URL resolves
- The plugin's assets are present
- No `href="#"` anywhere

Then per page, by eye: open in the editor and look for recovery prompts, check
375px / 768px / 1440px, and check body text contrast against its real background.

Report what passed and what did not. Do not call it finished until all of it does.

---

## Throughout

- Never ask for a password in chat, and never read or write a `.env`.
- Never regenerate a site config that has entries in `pages` or `media`.
- If the host caches, purge after the push or you will see stale pages and think
  the push failed.
