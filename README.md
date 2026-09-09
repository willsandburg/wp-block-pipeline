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
/wp-start
```

It asks whether the site is local, live, or both, then sets up only what that
needs — no Docker unless you want a local preview. Then it interviews you about
the site and walks through generating and pushing it, stopping so you can look
at the output before it goes further.

| | |
| --- | --- |
| `/wp-start` | Set up a site end to end. The main entry point. |
| `/wp-push` | Push styles, media and pages in the right order. |

---

## What you need

You are asked where the site runs before anything gets installed. Three
options, in order of preference:

| Option | You need | You do |
| --- | --- | --- |
| **Local preview** (recommended) | Node 20.18+ | Nothing. It sets itself up. |
| **A site you already have** | WordPress, SSL, an app password | One terminal command to connect. |
| **Local with Docker** (advanced) | Docker Desktop | One file copy, one command. |

**The local preview needs no terminal at all.** It runs WordPress through the
Playground runtime — no Docker, no MySQL, no Apache — and everything is set up
inside the Claude Code window.

**Use a site you already have when the build needs to match production.** Most
hosts have one-click staging, and it runs the same WordPress and PHP versions
the site ships on, which is the only place block validation tells you anything
definitive.

**Live and staging sites** need SSL on with HTTPS forced, and an Application
Password. WordPress hides Application Passwords entirely without SSL, so that
one is not optional.

### One prompt, on the Docker path only

Claude Code often has a rule denying agent access to `.env` files. It is a good
rule and this plugin does not ask you to change it. Instead it writes
`env.staged.txt` and gives you one line to run. Playground needs no `.env` at
all.

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
