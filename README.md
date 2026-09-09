# WordPress block pipeline

Build WordPress sites with Claude and hand them off to clients who can edit them.

Core blocks and generated global styles, pushed over the REST API. No page
builder, no per-site licence, and the client edits in Gutenberg — which is
already on their site and costs them nothing.

---

## Install

Inside Claude Code:

```
/plugin marketplace add willsandburg/wp-block-pipeline
/plugin install wp-block-pipeline@wp-block-pipeline
```

Restart Claude Code. That's the whole install — no terminal, no copying files.

To confirm it worked, type `/` and look for `wp-start`.

---

## Use

```
/wp-start                             set up a local site
/wp-start https://example.com         connect to a live site
```

It reads the rules, sets up the environment, interviews you about the site, and
walks through generating and pushing it, stopping so you can look at the output
before it goes further.

| | |
| --- | --- |
| `/wp-start` | Set up a site end to end. The main entry point. |
| `/wp-verify` | Verify block markup against your WordPress version. Run once before your first site. |
| `/wp-push` | Push styles, media and pages in the right order. |

---

## What you need

**Local sites:** Docker Desktop, or Docker Engine plus Compose on Linux.
Nothing else — no PHP, no MySQL, no local WordPress.

**Live sites:** WordPress installed, SSL on and HTTPS forced, and an
Application Password. WordPress hides Application Passwords entirely without
SSL, so that one is not optional.

---

## How it works

Content is generated into a `site/` folder in your project and pushed over
REST. That folder is the source of truth, not the database. Change a page file,
push again, the page updates.

The design is a global styles object written to the database — no theme files,
no PHP, nothing on the filesystem. That is what makes it safe to run against a
client's host.

Generation is restricted to an approved list of core blocks, all with markup
verified against the pinned WordPress version. Anything not on the list is
refused rather than approximated. That constraint is what keeps the output from
breaking in the editor.

Sections can be locked so the client can edit text and swap images but cannot
restructure the layout. That is the handoff: they get real control over content
without the ability to take the page apart.

---

## First run

```
/wp-verify
```

Do this before your first client site. The block markup ships written from
documented save output rather than captured from a running install, and
WordPress 7.1 alone changed a lot. The command walks you through checking each
block and fixing what differs. About an hour, once per WordPress version.

---

## Stack

WordPress 7.1 (pinned) · Twenty Twenty-Five · core blocks only · global styles
in the database · Docker for local

Both the version and the theme are pinned by name on purpose. Block markup is
version-specific, and Twenty Twenty-Seven becomes the default on new installs
when WordPress 7.2 ships around December 2026.

---

## Uninstall

```
/plugin uninstall wp-block-pipeline
```
