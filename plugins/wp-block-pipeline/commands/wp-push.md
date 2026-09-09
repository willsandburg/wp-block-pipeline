---
description: Push generated styles, media and pages to a WordPress site in the correct order, then verify.
argument-hint: "[local | live]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Push to WordPress

Target: **$ARGUMENTS** (default local if blank)

## Before pushing

Read `references/allowed-blocks.md` and confirm everything in `site/pages/`
uses only approved blocks. If any page contains `core/html`, `core/shortcode`,
an unapproved block, or a hardcoded value where a preset variable belongs, stop
and report it. Do not push it and do not silently fix it — tell me which page
and which block.

Load the right config: `site/site.json` for local, `site/site.live.json` for
live.

If pushing live, confirm with me first, and confirm a backup exists.

## Order — this is not optional

1. **Global styles.** Pages reference preset slugs, so the presets must exist
   first.
2. **Media.** Image and Cover blocks embed attachment IDs. The attachment must
   exist before the markup referencing it. Skip files already recorded in the
   config unless the source changed.
3. **Pages.** If a page already has an ID in the config, POST to that ID to
   update. If not, create it and **record the new ID immediately** — a page
   created without its ID recorded gets duplicated on the next push.

Every step should be idempotent. Running this twice should change nothing the
second time.

## After pushing

- If the host caches (SG Optimizer, a CDN), purge it. Otherwise stale pages look
  like a failed push.
- Report what was created versus updated, with IDs.
- Remind me to open each page in the editor and check for block recovery
  prompts.

## Never

- Never delete or regenerate a config file that has entries in `pages` or
  `media`.
- Never push live without confirming first.
- Never put credentials in the transcript.
