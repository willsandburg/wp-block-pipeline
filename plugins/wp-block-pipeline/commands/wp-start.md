---
description: Set up a WordPress block pipeline site end to end — local or live. Run this first on any new site.
argument-hint: "[site URL, or leave blank for local]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, WebFetch
---

# Start a WordPress block pipeline site

Target: **$ARGUMENTS**

If that is blank, this is a local Docker site. If it is a URL, this is a live
site.

Work through the phases below. Stop and ask before moving to the next phase if
something fails — do not improvise around a failure.

---

## Phase 0 — Load the rules

Read these before doing anything else:

- `references/wp-blocks-stack.md` — the procedure
- `references/allowed-blocks.md` — the only blocks permitted, and the rule
- `references/global-styles.md` — the design system shape
- `references/wp-design.md` — design standard

These are binding, not advisory. In particular: only approved blocks may be
emitted, `core/html` and `core/shortcode` are banned outright, and hardcoded
values instead of preset variables are banned. If something is asked for that
has no approved block, refuse in the four-part shape given in
`allowed-blocks.md` rather than improvising.

## Phase 1 — Environment

**Local:** copy the files from `references/assets/` into the project root,
substitute the slug, then `docker compose up -d` and run `bootstrap.sh`
(`bootstrap.ps1` on Windows PowerShell). Detect which shell is available rather
than assuming.

**Live:** run `connect.sh` (or `connect.ps1`). It prompts for the URL, username
and application password. Do not ask for the password in chat — the script
takes it directly and keeps it out of the transcript.

If `connect.sh` reports a failure, read its message: it names the specific cause
(401 credentials, 403 firewall, 404 permalinks or REST unreachable). Report it
plainly and stop. Do not retry with variations.

## Phase 2 — Confirm the site is ready

Check and report:

- The site responds
- Twenty Twenty-Five is active
- The WordPress version, and whether it matches the pinned version
- The global styles record exists

If the global styles record is missing, tell me to open the Site Editor, change
any style, and save. That record cannot be created from outside.

If the WordPress version does not match the pin, say so clearly. The block
markup was verified against one version and is not guaranteed on another.

## Phase 3 — Has verification been done?

Check whether `references/allowed-blocks.md` still carries the unverified
warning. If it does, tell me the verification pass has not been run and that
`/wp-verify` does it.

Ask whether to run it now or proceed anyway. If proceeding, say once that
blocks may fail validation, then continue without repeating it.

## Phase 4 — Interview

Before generating anything, establish and record in `CLAUDE.md`:

1. The one thing a visitor should remember. Not a feature list, one thing.
2. Brand assets — ask for a logo, colours, fonts, and for anything to be
   dropped in `resources/design/`.
3. The page list, and what each page is for.
4. Editing posture — which sections the client may restructure, which are
   locked `contentOnly`.

Use AskUserQuestion. Do not skip this because it seems slow. A site generated
without it will be generic, and no amount of styling fixes that afterwards.

## Phase 5 — Global styles

Write `site/styles.json` per `references/global-styles.md`, derived from the
brand assets or the interview answers.

Push it, then **stop and tell me to look at the site.** Do not continue to
pages until I have confirmed the styling looks right. This is the highest
leverage step and the cheapest one to redo.

## Phase 6 — Pages

Media first, always — Image and Cover blocks embed attachment IDs, so the
attachments must exist first. Record every new page and attachment ID in the
site config immediately.

Then one page at a time, starting with home. After each push, tell me to look
at it before continuing.

## Phase 7 — Verify

For each page: open in the editor and check for block recovery prompts, check
the locking behaves as decided, check at 375px / 768px / 1440px, and check body
text contrast against its actual background.

Report what passed and what did not. Do not describe the site as finished until
all four pass on every page.

---

## Throughout

- Never regenerate a site config file that already has entries in `pages` or
  `media`. Those IDs are the only record of what is on the site.
- Never put credentials in chat, in `CLAUDE.md`, or in any committed file.
- Push to local before live where both exist.
- If I ask for something with no approved block, refuse and explain. Do not
  reach for `core/html`.
