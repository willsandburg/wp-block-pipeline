---
description: Set up a WordPress block pipeline site end to end — asks whether you want local, live, or both. Run this first on any new site.
argument-hint: "[optional site URL]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebFetch
---

# Start a WordPress block pipeline site

Argument, if given: **$ARGUMENTS**

Work through the phases in order. If a phase fails, stop and report what
failed — do not improvise around it or retry with variations.

---

## Phase 0 — Load the rules

Read these first:

- `references/wp-blocks-stack.md` — the procedure
- `references/allowed-blocks.md` — the only blocks permitted, and the rule
- `references/global-styles.md` — the design system shape
- `references/wp-design.md` — the design standard

Binding, not advisory. Only approved blocks may be emitted. `core/html` and
`core/shortcode` are banned. Hardcoded values where a preset variable belongs
are banned. If something is asked for with no approved block, refuse in the
four-part shape given in `allowed-blocks.md` rather than improvising.

## Phase 1 — Ask where this site runs

**Ask before installing anything.** Do not infer it from whether an argument
was passed. Use AskUserQuestion, and present the options in this order:

> Where do you want to build this site?
>
> - **Local preview** (recommended) — runs on this machine, needs only
>   Node 20.18+. Nothing for you to install or type; I set it up here.
> - **A site you already have** — a live site or a staging copy on your host.
>   Needs one terminal command to connect. Closest match to what the client
>   ends up with.
> - **Local with Docker** (advanced) — full MariaDB and Apache stack. Needs
>   Docker Desktop and one manual file copy. Only if you specifically want the
>   production stack locally.

Present them in that order. The first option is recommended because the person
does not have to leave this window: no terminal, no file copying, no
credentials to create.

If an argument was passed that looks like a URL, mention it as the default for
the second option, but still ask.

**Install nothing beyond what the chosen option needs.** Never set up Docker
unless Docker was explicitly chosen.

If they picked a local option, ask separately whether they also want to push to
a live site once it looks right.

## Phase 2 — Environment

### If Playground

**Do all of this yourself. The person types nothing.**

Check Node is 20.18 or newer. If it is not, say so plainly and offer the other
two options — do not tell them to go install Node unless they want to.

Copy `playground.sh`, `playground-connect.sh` and `blueprint.json` from
`references/assets/` into the project root, and make the scripts executable.
Nothing else is needed: no compose files, no `.env`, no bootstrap, no
credentials for them to create.

Run `./playground.sh` **in the background**. It starts the server, waits until
the site actually answers, and exits — it does not hold the terminal. First run
downloads the runtime and can take a couple of minutes, so tell them it is
starting and let it work.

If it fails, it prints the last 30 lines of `.playground.log`. Report the real
error rather than retrying.

When it reports the site is up, run `./playground-connect.sh` yourself. It
verifies REST, creates an application password, reads the global styles ID, and
writes `site/site.json`.

Then tell them the site URL **and the admin login, in full** — Playground's
defaults are username `admin`, password `password`. Do not make them go looking
for it: they cannot get into their own site without it, and the site's admin
email is `admin@localhost.com`, so signing in with their own address fails
confusingly. State it plainly, and say once that these defaults are fine for a
throwaway local sandbox and never acceptable on a real host.

Useful later: `./playground.sh --stop` and `--status`.

`blueprint.json` pins the WordPress version and sets
`WP_ENVIRONMENT_TYPE=local`, which is what allows application passwords over
plain http. Do not remove either.

### If Docker

Copy the files from `references/assets/` into the project root and substitute
the slug.

**Never write `.env` directly, and never read one.** Many people have a
settings rule denying agent access to `.env` files, and it is a good rule worth
keeping. Always write **`env.staged.txt`** instead.

Then get the absolute working directory with `pwd` and give the person **both
lines, with the real path filled in** — never "run this in the project root",
because they will very likely be in a different folder or a different terminal
tab:

> Run these two lines in a terminal, then tell me when it's done:
> ```
> cd /absolute/path/from/pwd
> cp env.staged.txt .env
> ```

Wait for confirmation. Do not attempt `.env` first to see whether it is
allowed, and do not suggest changing their permission settings.

**This applies to every terminal instruction in this command, not just this
one.** Always run `pwd` and prefix with a `cd` to the absolute path. Assume the
person is in a fresh terminal in their home directory, because they usually
are.

Detect whether Traefik is running and whether `.loc` resolves. If both, use
domain mode. Otherwise use port mode, and check the ports are free.

Then `docker compose up -d` and run `bootstrap.sh`, or `bootstrap.ps1` on
Windows PowerShell. Detect which shell is available rather than assuming.

### If live or both

Run `connect.sh` (or `connect.ps1`). It prompts for the URL, username and
application password.

**Do not ask for the password in chat.** The script takes it directly so it
stays out of the transcript.

If it reports a failure, read its message — it names the cause: 401 is
credentials, 403 is the host firewall or a security plugin, 404 is permalinks
set to Plain or REST unreachable. Report which and stop.

## Phase 3 — Confirm the site is ready

For whichever targets exist, check and report:

- The site responds
- Twenty Twenty-Five is active
- The WordPress version, and whether it matches the pinned version
- The global styles record exists

If the global styles record is missing, tell the person to open the Site
Editor, change any style, and save. It cannot be created from outside.

If the version does not match the pin, say so plainly. The block markup was
verified against one version and is not guaranteed on another.

## Phase 4 — Interview

Establish and record in `CLAUDE.md`:

1. The one thing a visitor should remember. Not a feature list, one thing.
2. Brand assets — ask for a logo, colours, fonts, and for anything to go in
   `resources/design/`.
3. **What the name means.** Ask where it comes from before deriving any visual
   direction from it. A name that reads as a place or a word will push the whole
   art direction one way, and guessing wrong is expensive — one site here was
   named after Highland, Utah and was very nearly given an entire Scottish
   Highlands art direction on an assumption.
4. The page list, and what each page is for.
5. Editing posture — which sections the client may restructure, which are
   locked `contentOnly`.

Use AskUserQuestion. Do not skip this because it feels slow. A site generated
without it will be generic, and styling does not fix that afterwards.

## Phase 5 — Global styles

Write `site/styles.json` per `references/global-styles.md`, derived from the
brand assets or the interview answers.

Push it, then go straight to Phase 5a. An empty site is not something anyone can
judge a design system by.

## Phase 5a — The style specimen

**Always. Every site, every time.** Copy `style-specimen.html` and `specimen.py`
from `references/assets/` into the project root and run:

```
python3 specimen.py site/site.json
```

It publishes one page carrying every style on the site: h1 through h6, body copy
at each size, secondary and centred text, bold, italic, inline links, both button
styles at rest, lists, a quote, a table, an FAQ, separators, the six palette
swatches, a grid, a wrapping row, unequal columns, the spacing scale, and
full-bleed accent and dark panels.

Then **stop and ask the person to look at it.** Do not continue to pages until
they confirm. This is the highest-leverage moment in the whole build and the
cheapest one to redo — every page after this inherits whatever they accept here.

Send them the URL and tell them what to do on it, because these are the things a
screenshot cannot show:

- hover every button, then Tab through them — rest, hover and keyboard focus are
  three separate states and all three must be visible
- open and close the FAQ
- drag the window from wide to phone width and watch the headline scale and the
  grid reflow

**Read it yourself before handing it over.** It is built to expose the four
failures that otherwise reach a finished page:

- **A filled button on the dark panel that matches the panel.** If the primary
  button's background is the same colour as the dark section, it stops looking
  like a button while the front end still "works". Fix it in the design system
  so every dark CTA on the site is fixed at once, not on the one page where it
  was noticed.
- **A link on the dark panel that vanishes.** Link colour is set once, for the
  light canvas. On a dark section it can land within a shade or two of the
  background, and the site footer is usually where it shows up — after the
  pages have all been signed off.
- **Secondary text that fails contrast** on the surface it actually sits on.
- **A ragged grid row.** `minimumColumnWidth` decides the column count from the
  space available. Pick one that divides the wide width cleanly — at a 76rem
  wide size, 22rem gives exactly three.
- **A heading that wraps past three lines at 375px.** Cap the top of the type
  scale rather than repairing it page by page later.

Once media exists (Phase 6), append the image section and re-push, so Image,
Cover and Media & Text are judged too:

```
python3 specimen.py site/site.json --with-media photo.jpg hero.jpg
```

The specimen's page ID is recorded under `specimen_page`, never under `pages`,
so `/wp-publish` will not push it to a live site. Remove it before handover:

```
python3 specimen.py site/site.json --remove
```

## Phase 5b — Put the brand assets in the project

Once they have accepted the styles, **copy the brand source files into
`resources/design/`** rather than leaving them scattered across the machine. A
later session cannot find a brand guide it was never told about, and asking the
person a second time where their logo lives is the kind of thing that makes the
tool feel like it has no memory.

Copy in whatever exists — brand guide, palette file, logo exports, fonts,
photography — and write `resources/design/SOURCES.md` recording, for each one,
where it came from and what it is authoritative for. Keep the original paths in
that file: the copies go stale, and the file is how anyone finds the current
version again.

`resources/design/` is gitignored except for `SOURCES.md`, deliberately. Client
photography and licensed fonts do not belong in a repository, but the record of
where they live does, and it survives a clone.

Then record in `CLAUDE.md` the brand rules that actually bind the build — the
name's exact spelling, any trademark the guide says to avoid, what may and may
not be claimed about the work shown, and any colour pairing the guide forbids.
**Where a brand rule and an instruction conflict, raise it before building, not
after.** Reading the guide properly at this point routinely turns up two or
three of these, and catching them is worth more than any styling decision.

## Phase 6 — Pages

Media first, always — Image and Cover blocks embed attachment IDs, so the
attachments must exist first. Record every new page and attachment ID in the
site config immediately.

Then one page at a time, starting with home. After each push, stop and ask them
to look.

Keep `site/pages/_pages.json` current as pages are added: site title, logo and
icon filenames, and each page's file, title and whether it is the front page.
`/wp-publish` reads it to push the same site to a live install.

## Phase 7 — Check the result

Run the mechanical checks first — most of this needs no browser. Per page:
approved blocks only, exactly one `h1`, no skipped heading levels, `alt` on
every image, no hardcoded px or hex, both preset syntaxes present and agreeing,
every colour slug existing in the palette, every attachment ID present in the
library. This catches things reading the page will not, such as an `h1 -> h3`
skip.

Then per page, by eye: open in the editor and check for block recovery prompts,
check the locking behaves as decided, and check body text contrast against its
**actual** background — for a Cover that means measuring the image's brightest
band, not its average, because an average hides the one region where white text
fails.

**Then check 375px, 768px and 1440px, in that order.** Start at 375: it is the
width that breaks things, and a layout that survives it usually survives the
rest. Look specifically for a heading wrapping past three lines, a grid that
refused to reflow, a Cover whose subject has been cropped out, and hero text
that reads as misaligned. The rules that prevent all four are in
`references/wp-design.md` under "Mobile is not a checkpoint" — apply them while
generating rather than repairing afterwards.

Template parts are not covered by the page checks. Look at the header and footer
too: a stock block theme ships demo navigation links pointing at `#`, and
shipping those is the same failure as shipping demo content.

Report what passed and what did not. Do not call the site finished until all
four pass on every page.

Then remove the specimen — it is a working reference, not site content:

```
python3 specimen.py site/site.json --remove
```

---

## Throughout

- **Never write or read `.env`.** Stage it and have the person copy it.
- Never regenerate a site config that has entries in `pages` or `media`. Those
  IDs are the only record of what is on the site.
- Never put credentials in chat, in `CLAUDE.md`, or in any committed file.
- Where both local and live exist, push local first.
- If asked for something with no approved block, refuse and explain. Do not
  reach for `core/html`.
