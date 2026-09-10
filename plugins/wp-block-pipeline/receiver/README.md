# Receiver plugin

The site-side half of the pipeline. One plugin, one namespace, on every site the
pipeline builds.

**Do not generate a per-site copy.** A fix found in month six has to reach every
site already built, and that is only possible if they all run the same plugin.
A per-site namespace also breaks the verified markup in `allowed-blocks.md`,
which is checked against this implementation.

## What it provides

**`highlandsites/form`** — a contact form block. Dynamic: `save()` returns null,
so the stored markup is only the block comment and it cannot fail validation. The
form is a plain HTML POST, so it works with JavaScript disabled. Submissions are
stored as private posts **and** emailed; storing first matters because hosts drop
outgoing mail and a form that loses enquiries is worse than none. Nonce,
honeypot, a three-second minimum and a per-IP rate limit, in that order.

**Scroll-triggered reveals** — IntersectionObserver adds a class on entry and a
CSS transition does the rest. Not `animation-timeline: view()`, which is
scroll-*linked* and freezes half-finished when scrolling stops.

## What it deliberately does not provide

**CSS.** Presentation lives in global styles, which pushes over REST in seconds.
Plugin CSS can only be updated by re-uploading the zip, so a one-line spacing fix
becomes a round trip through wp-admin. JavaScript stays here because it changes
rarely; CSS does not.

## It is additive, not load-bearing

Deactivate it and the form block stops rendering and the reveals stop. Every
other page still works — they are core blocks, and the styling is in the
database. Nothing on the site breaks.

## Building

    ./build.sh

**`highlandsites.zip` is committed here on purpose** — it is the only way to get
the plugin onto a site today, and shipping it with the skill means nobody has to
build anything. The cost is that it can go stale: **edit any PHP file and rerun
`./build.sh` in the same commit**, or a client uploads code that does not match
the source, which is the exact drift this pipeline exists to prevent.

That disappears once the plugin is listed on wordpress.org, at which point
`POST /wp/v2/plugins {"slug": "..."}` installs it remotely and the zip can go.

Then upload through **Plugins → Add New → Upload Plugin**. WordPress refuses
remote installation of arbitrary zips; only a wordpress.org slug can be installed
over REST.
