---
name: wp-block-pipeline
description: Build a WordPress site by generating core blocks and global styles and pushing them over the REST API, then hand it off to a client who edits it in Gutenberg. Use this whenever the task involves building, generating, styling or pushing a WordPress site, creating pages or sections as Gutenberg blocks, setting up a local WordPress environment with Docker, connecting to a live WordPress site, or handing a finished site to a client who needs to edit it themselves. Also use it for any question about which blocks are allowed, how global styles work, or why a block shows "Attempt Block Recovery".
---

# WordPress block pipeline

Generate a WordPress site as core blocks and global styles. Push it over REST.
Hand the client a site they can edit in Gutenberg with no page builder and no
subscription.

**This is not the classic-theme approach.** No theme files are written, no PHP
templates, no SFTP. WordPress runs from a Docker image or an existing host, the
bundled block theme provides the structure, and the design lives in global
styles in the database.

---

## Start here

Run `/wp-start` and follow it. It sequences everything below.

If working manually, read
[references/wp-blocks-stack.md](references/wp-blocks-stack.md) — that is the
complete procedure.

---

## The rules — binding, not advisory

**Only approved blocks may be emitted.** The list is in
[references/allowed-blocks.md](references/allowed-blocks.md). A block existing
in WordPress does not make it permitted. Read that file before writing any
markup.

**`core/html` and `core/shortcode` are banned outright**, including as a
workaround when something is missing. They bypass validation and produce blocks
the client cannot edit, which defeats the point of the whole approach.

**Spacing and colour come from preset variables, never hardcoded.** A pixel
value in block markup cannot be changed by the client and ignores the design
system.

**When something has no approved block, refuse.** Compose from approved blocks
first — most requests that look like they need a new block do not. If
composition genuinely cannot do it, refuse in the four-part shape given in
`allowed-blocks.md`: what was asked, why it is not available, the closest
approved alternative, and how to add it. Do not improvise.

The reason for all of this is narrow: markup that has not been verified against
the running WordPress version fails validation and shows the client "Attempt
Block Recovery" on a page they cannot fix. One unverified block ruins the
handoff.

---

## The reference files

| File | Read it when |
| --- | --- |
| [references/wp-blocks-stack.md](references/wp-blocks-stack.md) | The full procedure. Start here for any build. |
| [references/allowed-blocks.md](references/allowed-blocks.md) | Before writing any block markup. Always. |
| [references/global-styles.md](references/global-styles.md) | Building the design system for a site. |
| [references/wp-design.md](references/wp-design.md) | Any layout or visual decision. |
| [references/local-environment.md](references/local-environment.md) | Docker setup, or something will not start. |

`references/assets/` holds the files copied into each new project: the compose
files, `bootstrap` and `connect` scripts, `.env.example`, `.gitignore`,
`.gitattributes`.

---

## The commands

| | |
| --- | --- |
| `/wp-start` | Set up a site end to end, local or live. The main entry point. |
| `/wp-verify` | The block verification pass. Run once per pinned WordPress version. |
| `/wp-push` | Push styles, media and pages in the correct order. |

---

## The stack

Fixed. Do not substitute without changing the reference files.

| | |
| --- | --- |
| WordPress | 7.1, pinned |
| Theme | Twenty Twenty-Five, bundled with core, activated by name |
| Blocks | core only, restricted to the approved list |
| Design | global styles in the database, never files |
| Local | Docker, ports by default |

The version and theme are pinned deliberately. Block save output changes
between releases, and Twenty Twenty-Seven becomes the default on new installs
when WordPress 7.2 ships around December 2026.

---

## Things that go wrong, and why

**A block shows "Attempt Block Recovery."** Its markup does not match what the
block's save function produces. Fix it in `allowed-blocks.md`, not in the page —
every future site inherits the error otherwise.

**Styling does not apply.** Either the theme is a classic theme rather than a
block theme, or the markup used hardcoded values instead of preset variables.

**A push creates a duplicate page instead of updating.** The page ID was not
recorded in the site config. Never delete or regenerate a config file that has
entries in `pages` or `media` — those IDs are the only record of what is on the
site.

**REST returns 401, 403 or 404.** Respectively: wrong credentials, the host's
firewall or a security plugin, or permalinks set to Plain. `connect.sh` reports
which.

**Application Passwords are missing from the user profile.** The site is not on
HTTPS. WordPress disables the feature entirely without SSL.

---

## Before the first client site

The markup in `allowed-blocks.md` was written from documented save output, not
captured from a running install. Run `/wp-verify` once against the pinned
WordPress version and fix what differs. It takes about an hour and it is the
difference between a reliable pipeline and one that breaks in front of a client.
