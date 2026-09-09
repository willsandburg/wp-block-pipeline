# Session learnings — 9 September 2026

Findings from building highlandsites.com with v0.5.0 on Playground. Kept as a
running list so improvements are not rediscovered next time.

Status: **fixed** = already changed in this repo · **pending** = not yet done.

---

## Fixed in this session

### 1. Playground could never authenticate  ·  fixed

`playground-connect.sh` tried to create the first application password over REST
using `admin:password`. That can never work: WordPress accepts application
passwords for REST Basic auth and **never** a user's real login password, so
creating the first one over REST is a chicken-and-egg. It failed identically on
every Playground site, which means the recommended path was broken end to end.

**Fix:** `blueprint.json` mints the credential in-process with a `runPHP` step at
boot and writes it to `/wordpress/pipeline-credential` — outside `wp-content`, so
it is not web-accessible. `playground-connect.sh` reads it from the host side of
the mount, copies it into `site/site.json`, and deletes it. The mount path is
parsed from the `Mount` line in `.playground.log` rather than guessed.

### 2. The global styles ID was never found  ·  fixed

`playground-connect.sh` grepped for `global-styles/[0-9]+`, but WordPress escapes
forward slashes in JSON, so the href reads `global-styles\/5`. The grep could
never match. Every run wrote `"global_styles_id": null` and told the user to go
save something in the Site Editor that already existed.

### 3. The admin login was never surfaced  ·  fixed

Nothing told the user the credentials, and Playground's admin email is
`admin@localhost.com`, so signing in with their own address fails confusingly.
`wp-start.md` now states `admin` / `password` explicitly, and the script prints
it. This cost a real detour.

### 4. `align` was missing from the block reference  ·  fixed

`allowed-blocks.md` documented no `align` attribute, so every block would render
at `contentSize` — a hero image in a 672px column. The other docs assume it
exists (`global-styles.md` defines `wideSize` as "what a wide-aligned block
expands to"; `wp-design.md` puts "Everything at `wideSize`" on the refuse list).
Verified on 7.1 and added as an Alignment section.

---

## Pending

### 4b. `dimRatio` on Cover needs a matching level class  ·  fixed

The single worst failure of this build. Cover's `save()` emits
`has-background-dim-{10 × round(ratio ÷ 10)}` for every `dimRatio` except 50.
Using 55 without `has-background-dim-60` made **five of six page headers** show
"Attempt Block Recovery" in the editor.

Three things made it expensive:

- **The front end rendered perfectly.** Nothing was visibly wrong until the
  editor was opened, so it survived several rounds of visual review.
- **The mechanical audit passed all six pages.** It checked approved blocks,
  headings, alt text, presets and slugs — but never attribute *values*. An audit
  that reports PASS on a broken page is worse than no audit.
- **The first diagnosis was wrong.** `minHeight` was the obvious suspect because
  it was the attribute added on judgement rather than from the reference, and it
  was removed on a hunch instead of by bisection. The actual variable was visible
  the whole time: the one working page used 50, every failing page used 55.

Bisect. The comparison that solved it took one command and should have been the
first move, not the third.

### 4c. The audit must check attribute values, not just block names  ·  fixed

Add to the mechanical checks: `dimRatio` is 50 or carries the matching level
class; no attribute outside the documented set for each block. Both failures in
this build would have been caught before push.

### 5. `.env.example` breaks bootstrap on any multi-word site name

`WP_TITLE={Site name}` is unquoted, and `bootstrap.sh` does `set -a; source .env`.
A real title fails with `Sites: command not found`. Quote it — and audit the
whole file for other unquoted values.

### 6. `minHeight` was removed, not disproved  ·  resolved differently

Both are in use and neither is in the verified list. Cover's default height
letterboxes a 3:2 image into a strip, so `minHeight` is not optional in practice.
`align` on Columns is needed for any asymmetric split wider than the text column.

### 7. Document `page-no-title`

Twenty Twenty-Five's `page` template renders `post-title` as an `h1`, so any page
with its own hero headline ships **two `h1`s** — an accessibility defect, and the
pipeline's own design doc forbids it. TT5 already ships a `page-no-title`
template; assigning it via the page's `template` field fixes the duplicate *and*
removes the `spacing|60` margin and padding that leave a large gap above the hero.
This should be the default for any page whose content starts with a hero.

### 8. There is no approved block for code

`core/code` and `core/preformatted` are both absent, so a page cannot show block
markup or a config sample. It cannot be composed — Paragraph collapses whitespace
and Table breaks on phones. This bites immediately on any developer-facing site.
`core/code` is small and stable; a good candidate for the next verification pass.

### 9. Fold a mechanical audit into Phase 7  ·  fixed — `assets/audit.py`

Most of Phase 7 can be checked without opening a browser: approved blocks only,
one `h1`, no skipped heading levels, `alt` on every image, no hardcoded px or hex,
both preset syntaxes agreeing, colour slugs existing in the palette, attachment
IDs present in the library. This caught a real `h1 -> h3` skip that reading the
page would not have. Worth shipping as a script in `assets/`.

### 10. Measure Cover contrast against the brightest band, not the average

Averaging a landscape hides the failure. On the hero used here the average
suggested `dimRatio` 40 was fine, while the sky band actually needed 45 for AA
and 60 for AAA. Resize the image to 1px wide by N tall — each pixel is then a
band average — and set `dimRatio` from the brightest one.

### 11. Twenty Twenty-Five self-hosts only Manrope and Fira Code

`global-styles.md` says to self-host via `fontFace` with a `file:./` path, but a
generated site has no font files and cannot write them. Referencing the theme's
two registered families is the only zero-risk route to no-fallback typography.
Worth stating, along with the Font Library REST route for anything else.

### 12. WordPress rejects SVG uploads

Correct default, and worth documenting so nobody tries to ship an SVG diagram.
Rasterise first — but ImageMagick may have no fonts configured, so SVG containing
text fails. Prefer composing visuals from approved blocks.

### 13. Marketplace updates are not automatic

The installed plugin sat at 0.1.0 while this repo was 0.5.0, and `/wp-start`
silently ran the old rules — old command, old references, a since-fixed MariaDB
bug. `claude plugin marketplace update <name>` fixes it. The skill should say so,
and `plugin update <name>` needs the `plugin@marketplace` id, not the bare name.

---

## Added after the first live deploy

### 14. Page markup is not portable between sites  ·  fixed — `assets/deploy.py`

The single biggest gap. `wp-blocks-stack.md` says of a live push: "Everything
else is identical: styles, then media, then pages." **That is not true.** Page
markup embeds attachment IDs (`"id":8`, `wp-image-8`, `"mediaId":9`) and
absolute upload URLs. Push the same files to a second site and every image
breaks and every Cover fails validation, because those IDs belong to the site
they were generated against.

`deploy.py` uploads media to the target first, then rewrites every ID, upload URL
and internal page link before the pages go up. It does the swap in two passes via
placeholders — a local ID can collide with a live one (local 8 → live 12 while
local 12 also exists) and naive sequential replacement corrupts it.

Internal links matter too: a button pointing at `http://127.0.0.1:9400/output/`
survives the media swap and ships a link to the developer's laptop.

### 15. Fix a bug everywhere it exists, not where you found it

The escaped-slash grep that broke the global styles lookup existed in **both**
`playground-connect.sh` and `connect.sh`. One was fixed early, shipped, and
forgotten; the other silently reported `global_styles_id: null` on the live
deploy, on a site where the record existed as ID 7.

Whenever a bug is fixed in an asset, grep the whole assets folder for the same
pattern before moving on.

### 16. Reach for a class and plugin CSS before an unverified attribute

The most useful pattern of the session, and it is written down nowhere.

When something needs styling the verified block markup cannot express — a hero
height, a rounded card, a hover state — the instinct is to add an attribute
(`minHeight`, `style.border.radius`). That is unverified markup and it fails in
the editor while looking perfect on the front end.

**Add `className` and write the CSS in the plugin instead.** `className` is a
universal support, appears only in the class list, and cannot mismatch. The CSS
lives in one place, is editable, and respects `prefers-reduced-motion`. Hero
heights, card styling, step hovers and the nav underline on this build all work
that way.

### 17. Template parts are invisible to the page audit

`audit.py` reads `site/pages/*.html`. The header and footer are not page content,
so a stock block theme's **eight demo navigation links pointing at `#`** passed
every check and would have shipped. Phase 6 of `/wp-publish` covers this by hand;
better would be an audit mode that fetches the rendered page and looks for
`href="#"`, demo strings and the theme's own name in the credit line.

### 18. Alt text does not travel with the media file

Uploading an image to a second site creates a fresh attachment with empty
`alt_text`. Page markup keeps its own `alt`, so page images are fine — but the
**site logo's alt comes from the attachment**, so it silently ships empty.
`site.json` now stores alt per file and `deploy.py` carries it across.

### 19. Scroll-linked is not scroll-triggered

Worth stating plainly because it wasted three rounds. CSS
`animation-timeline: view()` is scroll-**linked**: progress is bound to scroll
position, so it freezes half-finished when scrolling stops and reverses when you
scroll back. It is a scrubber, not an animation.

What people mean by "fade in on scroll" is scroll-**triggered**: an element
enters the viewport and a normal time-based animation plays on its own clock.
**There is no CSS-only way to do that today** — it needs IntersectionObserver.
Do not offer a CSS reveal as if it were the same effect.

Second trap: a view timeline scales to the element's own height. Attaching a
reveal to a 2000px page section spreads the fade across ~500px of scrolling and
looks like nothing is happening. Animate content elements, not sections.

### 20. Verify a checker against known-bad input

`audit.py` passed all six pages while `dimRatio` was broken on every one. A check
that has only ever been run against good input is not evidence of anything.
Deliberately break a copy — wrong `dimRatio`, an undocumented attribute, a banned
block, a hardcoded pixel — and confirm each one is caught.

### 21. Bisect before theorising

The `dimRatio` failure cost two wrong fixes. The deciding comparison — one page
works, five do not, what differs — was one command and should have been the first
move. When several things fail and one succeeds, diff them before forming a
hypothesis.

### 22. Rasterising an SVG needs explicit width and height

The marks use a `0 0 64 64` viewBox with no dimensions, so ImageMagick rendered
them at 64px and upscaled 8×. The logo shipped blurry and was *larger* on disk
because of the upscaling artefacts. Set `width`/`height` on the SVG before
rasterising. Also: ImageMagick here has no fonts configured, so any SVG
containing text fails outright — build visuals from blocks instead.

### 23. Design traps that cost a round each

- **Portrait images in Media & Text.** A 2:3 image at 50% width runs very tall
  and the text floats in the vertical middle beside it. Crop to a band, or put
  the image between two text sections instead.
- **Centred long body copy** is harder to read than ranged left — the eye loses
  the line start. Fine for headings and short leads; say so when the client asks
  for everything centred.
- **Details blocks default closed.** An open first item makes the set look
  ragged and pushes the rest down.
- **Centre a CTA's heading, paragraph and button together or none of them.** A
  centred button under ranged-left text reads as broken.
- **Cards in a grid need `margin-top:auto` on the button** so buttons align when
  the descriptions differ in length — and keep aligning when the client edits.
- **Page List is alphabetical.** Set `menu_order` or the nav reads About, Home,
  Services, The output.

### 24. Ask where the brand name comes from

The interview establishes the one thing to remember, brand assets, pages and
editing posture. It does not ask what the name *means*. "Highland Sites" was read
as the Scottish Highlands and an entire painted art direction was built on lochs
and bothies — the client lives in Highland, Utah. Kept deliberately in the end,
but it was luck rather than judgement. One question would have caught it.

### 25. Still open: publishing the plugin to wordpress.org

The last piece of manual friction. WordPress refuses remote installation of
arbitrary zips — `/wp/v2/plugins` accepts only a wordpress.org `slug` — so every
client must upload the zip by hand through wp-admin. Listing the plugin makes
that one REST call, and the whole publish flow becomes hands-off.

### 26. Still open: is the Site Editor save actually required?

Every doc says the global styles record does not exist until someone opens the
Site Editor and saves. On the live site the record existed as ID 7 — but
`connect.sh`'s grep bug meant it reported `null` regardless, so this has never
actually been tested on 7.1. If the record is created on theme activation, a
prerequisite can be deleted from the flow.
