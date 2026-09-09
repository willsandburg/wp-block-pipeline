# Allowed blocks

The complete list of blocks that may appear in generated output, and the rule
governing what happens when a request needs something not on it.

Read this before writing any block markup. It is the authority on what is
permitted — not your general knowledge of WordPress, and not what the target
site happens to have installed.

**Verified against WordPress 7.1 with Twenty Twenty-Five.** Block save output
changes between releases, so this file is version-specific. If a target site
runs a different major version, the markup here is not guaranteed — see
"Re-verifying after a WordPress upgrade" at the end of this file.

---

## The rule

**Only the blocks listed in this file may be emitted. Nothing else.**

This is a whitelist, not an availability check. A block existing in WordPress
core, in the Gutenberg plugin, or in a plugin installed on the target site does
not make it permitted. If it is not listed below with validated markup, it is
not available.

The reason is narrow and worth understanding: every block below has markup that
has been checked against the block's own save output. Markup that has not been
checked fails validation in the editor and greets the client with "Attempt Block
Recovery" — a broken-looking page they cannot fix. One unvalidated block ruins
the handoff that the entire pipeline exists to deliver.

### Composition comes first

Most requests that look like they need a new block do not. Before refusing,
work out whether approved blocks compose into the thing being asked for.

| Asked for | Built from |
| --- | --- |
| Testimonial | Group → Quote + Image |
| Feature grid | Group (grid layout) → Groups → Heading + Paragraph |
| Hero | Cover → Heading + Paragraph + Buttons |
| Pricing table | Group (grid layout) → Groups → Heading + List + Button |
| Stats row | Group (flex layout) → Groups → Heading + Paragraph |
| FAQ | Details, repeated |
| Logo strip | Group (flex layout) → Images |
| Two-column feature | Media & Text |
| CTA band | Group with background → Heading + Paragraph + Buttons |

Composition is the expected route. Refusal is for the genuine remainder.

### Banned outright

These are never permitted, including as a workaround when something is missing.
They are the escape hatches, and using one silently defeats the whole rule.

- **`core/html`** — accepts arbitrary markup, so it bypasses the whitelist
  entirely. It also produces a block the client cannot meaningfully edit, which
  is the opposite of the point. WordPress 7.1 improved this block by letting
  supported blocks stay editable inside its preview. That does not lift the
  ban: the problem was never the preview, it was arbitrary markup escaping
  validation.
- **`core/shortcode`** — same bypass, via PHP.
- **Inline `style` attributes** that are not generated from a preset variable.
  Hardcoded colours, fonts and pixel values break the global styles system and
  cannot be changed by the client later.
- **Custom CSS** written into global styles to achieve something a block cannot
  do. If it needs custom CSS, it needs a block, and that is a request to add one.
- **Experimental blocks**, including the `core/form` family. They change without
  deprecation paths, so markup generated today fails validation later.
- **Blocks from plugins on the target site**, even good ones. The site's plugin
  set is not stable across clients.

### Styling the verified markup cannot express

Before reaching for an attribute that is not documented for a block, reach for a
class instead.

When a hero needs a particular height, a card needs rounded corners, or a row
needs a hover state, the instinct is to add an attribute — `minHeight`,
`style.border.radius`, a different `dimRatio`. **That is unverified markup.** It
renders perfectly on the front end and fails validation the moment the client
opens the editor, which is the exact failure this file exists to prevent.

Add `className` and put the CSS in the plugin:

```html
<!-- wp:cover {"url":"...","id":8,"dimRatio":50,"isDark":true,"align":"full","className":"hs-hero"} -->
<div class="wp-block-cover alignfull hs-hero">
```

```css
.hs-hero{min-height:45vh}
@media (max-width:600px){.hs-hero{min-height:52vh}}
```

`className` is a universal block support. It appears only in the class list, so
it cannot mismatch what `save()` produces. The CSS lives in one place, the client
can still edit everything inside the block, and media queries and interaction
states become available — none of which an attribute gives you.

Use it for heights, radii, shadows, hover and focus treatments, equal-height
cards, and anything responsive the fluid scale does not cover. Do **not** use it
to fake a block that does not exist; that rule is unchanged.

### JavaScript — allowed, but say what it costs first

JavaScript is permitted **only** when an effect genuinely cannot be built from
approved blocks and global styles, and **only** from the plugin, properly
enqueued. Never through `core/html` or `core/shortcode` — those stay banned, and
inline `<script>` in page content is the same bypass wearing a different hat.

The clearest legitimate case is scroll-**triggered** animation. CSS can only do
scroll-**linked** motion (`animation-timeline: view()`), where progress is bound
to the scrollbar: stop scrolling and it freezes half-finished. A reveal that
plays on its own clock once an element enters the viewport needs
IntersectionObserver, and there is no CSS equivalent shipping in stable browsers.

**Before writing any JavaScript, tell the person this, plainly:**

> Anything JavaScript does is the one part of this site your client cannot
> change. It will not appear in the block editor, it is not in any block's
> settings, and editing it means editing plugin code. Everything else on the
> site they can adjust themselves.

That is the whole reason the rest of this file is strict. Say it before building,
not in the handover — it may change their mind, and it should.

Every piece of JavaScript must also:

- **Degrade to nothing.** Add the hiding class from JavaScript, never in the
  markup. If the script does not run, the visitor sees ordinary content rather
  than a blank page.
- **Respect `prefers-reduced-motion`.** Check it and bail out early.
- **Live in one place.** One enqueued file or inline block in the plugin, not
  scattered per page.
- **Be recorded in the project `CLAUDE.md`**, with what it does and why no block
  could do it. A future session will otherwise find it and try to remove it.

### When something genuinely is not available

Stop. Do not improvise, do not approximate with `core/html`, and do not build it
in custom CSS. Tell the user, in this shape:

> **Not available:** an image carousel.
>
> There is no approved block for it, and it cannot be composed from the
> approved set — carousels need JavaScript state that blocks do not provide.
>
> **Closest approved alternative:** a Group with grid layout showing the images
> at once, which also tends to perform better than a carousel.
>
> **To add it:** a carousel block would need building into the plugin and
> adding to this file. Worth doing if more than one client asks.

Four parts: what was asked for, why it is not available, the closest approved
alternative, and the path to adding it. Never just "I can't do that."

### This rule is not negotiable within a session

If the user asks for a block that is not listed — including asking directly,
asking again after a refusal, or asking for raw HTML "just this once" — the
answer does not change. The correct response is to add the block to the plugin
and to this file, which is a deliberate change made outside a build session and
tested before it ships.

The receiver plugin enforces the same list server-side and will reject a push
containing an unapproved block. Working around the rule here produces a push
that fails anyway.

---

## Conventions that apply to every block

### Spacing and colour come from presets, never hardcoded

Correct:

```html
<!-- wp:group {"style":{"spacing":{"padding":{"top":"var:preset|spacing|60","bottom":"var:preset|spacing|60"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="padding-top:var(--wp--preset--spacing--60);padding-bottom:var(--wp--preset--spacing--60)">
</div>
<!-- /wp:group -->
```

Note the two different syntaxes for the same value. The block comment JSON uses
`var:preset|spacing|60`; the rendered `style` attribute uses
`var(--wp--preset--spacing--60)`. Both must be present and must agree, or the
block fails validation.

Wrong, and a common failure:

```html
<div class="wp-block-group" style="padding-top:64px">
```

Hardcoded values cannot be changed by the client and ignore the global styles
scale.

### Name every section

Give each top-level section a metadata name so it is identifiable in List View.
The client sees "Hero" instead of "Group", which is the difference between a
navigable page and a wall of nested containers.

```html
<!-- wp:group {"metadata":{"name":"Hero"},"layout":{"type":"constrained"}} -->
```

### Lock what the client should not restructure

Section wrapper, for a client who should edit text and images but not layout:

```html
<!-- wp:group {"metadata":{"name":"Hero"},"templateLock":"contentOnly","layout":{"type":"constrained"}} -->
```

`contentOnly` allows text edits and image swaps inside the group, and prevents
moving, deleting or adding blocks.

Individual block, when the section is otherwise unlocked:

```html
<!-- wp:image {"lock":{"move":true,"remove":true}} -->
```

Default posture: lock structural sections `contentOnly`, leave body-content
areas unlocked. Decide per page and record it in the site's `CLAUDE.md`.

### Alignment — `align`

**Verified against WordPress 7.1 with Twenty Twenty-Five, 9 September 2026.**

Without `align`, every block renders at `contentSize`. A hero image sits in a
672px column and the page reads as a document rather than a site. This is the
attribute that lets a block escape the content width, and the rest of the design
guidance assumes it exists — `global-styles.md` defines `wideSize` as "what a
wide-aligned block expands to", and `wp-design.md` puts "Everything at
`wideSize`" on the refuse list. Both are meaningless without it.

The JSON carries `"align":"full"` or `"align":"wide"`; the element carries the
matching `alignfull` or `alignwide` class. Both must be present and agree.

Group, full width, with a background:

```html
<!-- wp:group {"align":"full","backgroundColor":"tertiary","layout":{"type":"constrained"}} -->
<div class="wp-block-group alignfull has-tertiary-background-color has-background">
</div>
<!-- /wp:group -->
```

The align class comes **first**, before the colour classes.

Cover, full width:

```html
<!-- wp:cover {"url":"...","id":8,"dimRatio":50,"isDark":true,"align":"full","layout":{"type":"constrained"}} -->
<div class="wp-block-cover alignfull">
```

Image, wide — the align class sits between the block class and the size class:

```html
<!-- wp:image {"id":9,"sizeSlug":"large","linkDestination":"none","align":"wide"} -->
<figure class="wp-block-image alignwide size-large">
```

Media & Text, wide:

```html
<!-- wp:media-text {"align":"wide","mediaId":9,"mediaType":"image"} -->
<div class="wp-block-media-text alignwide is-stacked-on-mobile">
```

**Use the contrast deliberately.** If everything is full-width, nothing is. A
full-bleed section reads as wide only because the section before it was at
`contentSize`.

**How this was verified.** A page containing all four aligned variants plus an
unaligned control was pushed and opened in the editor on the pinned version. No
block reported invalid content, which means Gutenberg re-ran each `save()` and
matched it against the stored markup. That is the failure this file exists to
prevent, so it is sufficient to approve the markup. It does not capture
byte-for-byte canonical output the way the Copy method does; if that is ever
needed, use the maintainer procedure at the end of this file.

---

## Layout blocks

### Group — `core/group`

The workhorse. Three layout types, and the choice between them is most of
page structure.

**Constrained** — children sit at the content width, full-width children can
break out. The default for page sections.

```html
<!-- wp:group {"metadata":{"name":"Section"},"layout":{"type":"constrained"}} -->
<div class="wp-block-group">
</div>
<!-- /wp:group -->
```

**Flex** — children in a row. Use for stat rows, logo strips, button groups,
anything horizontal.

```html
<!-- wp:group {"layout":{"type":"flex","flexWrap":"wrap","justifyContent":"center"}} -->
<div class="wp-block-group">
</div>
<!-- /wp:group -->
```

`flexWrap` is `"wrap"` or `"nowrap"`. `justifyContent` is `"left"`,
`"center"`, `"right"` or `"space-between"`. Add `"orientation":"vertical"` for
a vertical stack with gap control.

**Grid** — equal columns that reflow. Use for feature grids and card sets.
Prefer this over Columns when the items are equivalent.

```html
<!-- wp:group {"layout":{"type":"grid","columnCount":3}} -->
<div class="wp-block-group">
</div>
<!-- /wp:group -->
```

Use `"minimumColumnWidth":"20rem"` instead of `columnCount` for a grid that
chooses its own column count by available space. Better responsive behaviour,
and it needs no breakpoint handling.

**With a background**, using a palette colour:

```html
<!-- wp:group {"metadata":{"name":"CTA"},"backgroundColor":"accent","textColor":"base","style":{"spacing":{"padding":{"top":"var:preset|spacing|70","bottom":"var:preset|spacing|70"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group has-base-color has-accent-background-color has-text-color has-background" style="padding-top:var(--wp--preset--spacing--70);padding-bottom:var(--wp--preset--spacing--70)">
</div>
<!-- /wp:group -->
```

The class order matters. Colour classes, then `has-text-color`, then
`has-background`. Colour slugs must exist in the site's global styles palette.

### Columns — `core/columns` and `core/column`

For deliberately unequal columns. When columns are equal, use Group with grid
layout instead — it reflows better on narrow screens.

```html
<!-- wp:columns -->
<div class="wp-block-columns">
<!-- wp:column {"width":"60%"} -->
<div class="wp-block-column" style="flex-basis:60%">
</div>
<!-- /wp:column -->
<!-- wp:column {"width":"40%"} -->
<div class="wp-block-column" style="flex-basis:40%">
</div>
<!-- /wp:column -->
</div>
<!-- /wp:columns -->
```

Widths must be present in both the JSON and the `flex-basis` style, and must
agree. Add `{"isStackedOnMobile":false}` to the columns block only when
stacking is genuinely wrong, which is rare.

### Spacer — `core/spacer`

```html
<!-- wp:spacer {"height":"var:preset|spacing|50"} -->
<div style="height:var(--wp--preset--spacing--50)" aria-hidden="true" class="wp-block-spacer"></div>
<!-- /wp:spacer -->
```

Reach for group padding or `blockGap` before a Spacer. Spacers are fixed and do
not respond to screen size, so a page built on them looks wrong on a phone.
Acceptable for a deliberate one-off gap, never as the general spacing method.

### Separator — `core/separator`

```html
<!-- wp:separator -->
<hr class="wp-block-separator has-alpha-channel-opacity"/>
<!-- /wp:separator -->
```

The `has-alpha-channel-opacity` class is required. Omitting it fails validation.

---

## Content blocks

### Paragraph — `core/paragraph`

```html
<!-- wp:paragraph -->
<p>Text.</p>
<!-- /wp:paragraph -->
```

With alignment and a preset font size:

```html
<!-- wp:paragraph {"align":"center","fontSize":"large"} -->
<p class="has-text-align-center has-large-font-size">Text.</p>
<!-- /wp:paragraph -->
```

Every attribute in the JSON must have its matching class on the `<p>`. This is
the most frequent source of validation failures.

### Heading — `core/heading`

```html
<!-- wp:heading -->
<h2 class="wp-block-heading">Text</h2>
<!-- /wp:heading -->
```

Level 2 is the default and is omitted from the JSON. Any other level is
explicit:

```html
<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Text</h3>
<!-- /wp:heading -->
```

One `h1` per page. Do not skip levels — an `h2` never follows an `h4`.

### List — `core/list` and `core/list-item`

```html
<!-- wp:list -->
<ul class="wp-block-list">
<!-- wp:list-item -->
<li>First</li>
<!-- /wp:list-item -->
<!-- wp:list-item -->
<li>Second</li>
<!-- /wp:list-item -->
</ul>
<!-- /wp:list -->
```

Ordered lists use `{"ordered":true}` on the list block and an `<ol>` element.
Every item is its own block — a bare `<li>` inside the `<ul>` fails validation.

### Image — `core/image`

```html
<!-- wp:image {"id":123,"sizeSlug":"large","linkDestination":"none"} -->
<figure class="wp-block-image size-large"><img src="https://example.com/wp-content/uploads/2026/01/photo.jpg" alt="Descriptive alt text" class="wp-image-123"/></figure>
<!-- /wp:image -->
```

The `id` must be a real attachment ID, and it appears twice — in the JSON and
in the `wp-image-{id}` class. **Push media before pushing the page** so the IDs
exist. An image block referencing an attachment that is not in the library
renders but is not editable as an image.

With a caption, add before `</figure>`:

```html
<figcaption class="wp-element-caption">Caption text</figcaption>
```

`alt` is required on every image. Decorative images get `alt=""`, never a
missing attribute.

### Buttons — `core/buttons` and `core/button`

```html
<!-- wp:buttons -->
<div class="wp-block-buttons">
<!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link wp-element-button" href="https://example.com">Label</a></div>
<!-- /wp:button -->
</div>
<!-- /wp:buttons -->
```

A button is always inside a `buttons` wrapper, even when there is one of them.
Both `wp-block-button__link` and `wp-element-button` classes are required.

Outline style, for a secondary button:

```html
<!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button" href="#">Label</a></div>
<!-- /wp:button -->
```

### Quote — `core/quote`

```html
<!-- wp:quote -->
<blockquote class="wp-block-quote"><!-- wp:paragraph -->
<p>Quoted text.</p>
<!-- /wp:paragraph --><cite>Attribution</cite></blockquote>
<!-- /wp:quote -->
```

The quote's text is a nested paragraph block, not bare text. The `<cite>` sits
outside the paragraph, inside the blockquote.

### Cover — `core/cover`

Background image with content over it. The standard hero.

```html
<!-- wp:cover {"url":"https://example.com/wp-content/uploads/2026/01/hero.jpg","id":124,"dimRatio":50,"isDark":true,"layout":{"type":"constrained"}} -->
<div class="wp-block-cover"><span aria-hidden="true" class="wp-block-cover__background has-background-dim"></span><img class="wp-block-cover__image-background wp-image-124" alt="" src="https://example.com/wp-content/uploads/2026/01/hero.jpg" data-object-fit="cover"/><div class="wp-block-cover__inner-container">
</div></div>
<!-- /wp:cover -->
```

**`dimRatio` is not free-form, and this bites.** Core's `save()` adds a level
class alongside `has-background-dim` for every value except 50:
`has-background-dim-{10 × round(ratio ÷ 10)}`. So `dimRatio: 55` must carry
`has-background-dim-60` on the span, and `dimRatio: 70` must carry
`has-background-dim-70`. Only 50 needs no level class, which is why the markup
above uses it.

Get this wrong and every Cover on the site shows "Attempt Block Recovery" while
the front end looks perfect — the page renders correctly, so nothing reveals the
fault until someone opens the editor. If you change `dimRatio`, add the matching
class:

```html
<!-- wp:cover {"url":"...","id":124,"dimRatio":60,"isDark":true} -->
<div class="wp-block-cover"><span aria-hidden="true" class="wp-block-cover__background has-background-dim-60 has-background-dim"></span>
```

Note the level class comes **before** `has-background-dim`. Simplest safe route:
leave `dimRatio` at 50 and pick images that clear contrast at 50.

`dimRatio` is the overlay opacity, 0 to 100. Anything below 40 over a busy
photo will fail contrast on the text above it — check it rather than
guessing. `isDark` controls which default text colour the block assumes.

The `url` appears twice, in the JSON and the `src`. The `id` appears twice, in
the JSON and the `wp-image-{id}` class.

### Media & Text — `core/media-text`

Image on one side, content on the other. Use this instead of hand-building it
with Columns — it handles the stacking behaviour correctly.

```html
<!-- wp:media-text {"mediaId":125,"mediaType":"image"} -->
<div class="wp-block-media-text is-stacked-on-mobile"><figure class="wp-block-media-text__media"><img src="https://example.com/wp-content/uploads/2026/01/photo.jpg" alt="Alt text" class="wp-image-125 size-full"/></figure><div class="wp-block-media-text__content">
</div></div>
<!-- /wp:media-text -->
```

Add `"mediaPosition":"right"` to flip the sides, which also adds
`has-media-on-the-right` to the wrapper class.

### Details — `core/details`

Collapsible section. The approved way to build an FAQ.

```html
<!-- wp:details -->
<details class="wp-block-details"><summary>Question text</summary>
<!-- wp:paragraph -->
<p>Answer text.</p>
<!-- /wp:paragraph -->
</details>
<!-- /wp:details -->
```

Repeat one per question, wrapped in a Group. Add `{"showContent":true}` to have
the first one open on load.

### Table — `core/table`

```html
<!-- wp:table -->
<figure class="wp-block-table"><table><thead><tr><th>Header</th><th>Header</th></tr></thead><tbody><tr><td>Cell</td><td>Cell</td></tr></tbody></table></figure>
<!-- /wp:table -->
```

For genuine tabular data only. Never for layout — a table used for layout
breaks on phones and reads wrong to a screen reader.

---

## Plugin blocks

### Contact form — `highlandsites/form`

**Verified against WordPress 7.1, 9 September 2026.** Provided by the receiver
plugin, so it exists on pipeline sites and nowhere else.

```html
<!-- wp:highlandsites/form {"formId":"contact","submitLabel":"Send it"} /-->
```

That is the whole markup. **The block is dynamic — its `save()` returns null —
so the stored content is only the comment and there is nothing for the editor to
compare.** It cannot produce "Attempt Block Recovery" under any circumstances,
which is why a dynamic block is the right shape for anything with server
behaviour behind it.

Attributes: `formId` (unique per site), `submitLabel`, `successMessage`,
`recipient`. Supports `align: wide`.

The fields are fixed at Name, Email and Message. That is deliberate — every
extra field costs completions, and a contact form asking for more than those
three is asking for abandonment.

**It needs no JavaScript.** The form is a plain HTML POST to `admin-post.php`
which redirects back with a success or error flag, so it works with scripts
disabled. Do not "improve" it into a fetch call without a reason.

Submissions are stored as private `hs_submission` posts **and** emailed to the
site admin. Storing first matters: hosts drop outgoing mail regularly, and a
form that silently loses enquiries is worse than no form.

Protections, in the order they run: nonce, honeypot field, a three-second
minimum between render and submit, then a one-minute per-IP rate limit. All four
are cheap and none of them inconvenience a person.

---

## Candidates — not yet approved

Blocks that exist and look useful, but have **no verified markup yet**. They are
not on the whitelist and must not be emitted. Listed so the same evaluation is
not redone every time one comes up.

To approve one: build it in the editor on the pinned version, use the block's
Copy option, paste the markup into an approved section above with notes on its
required attributes, and delete it from here.

### Tabs — `core/tabs` (new in 7.1)

Tabbed content. A genuine candidate: it covers a real layout need that currently
has no approved equivalent, and it degrades to readable stacked content.

Evaluate before approving. Check how it behaves at 375px, whether tab panels are
keyboard navigable, and whether `templateLock: contentOnly` on a parent group
still allows editing text inside a panel. That last one decides whether it fits
the handoff model at all.

### Playlist — `core/playlist` (new in 7.1)

Audio playlists. Out of scope for marketing sites. Not worth evaluating unless a
client actually needs it.

### Table of Contents — `core/table-of-contents`

Planned for 7.1, pushed to 7.2. Revisit when the pinned version moves.

---

## Template-level blocks

Blocks that belong in site templates — Site Title, Site Logo, Navigation, Query
Loop, Post Content and their relatives — are **out of scope for page
generation**. Header and footer come from the base theme, configured once
during setup.

If a page genuinely needs one, that is a request to extend the pipeline, not
something to improvise into page content.

---

## Re-verifying after a WordPress upgrade

**Maintainers only. Not part of building a site.** Skip this unless you are
moving the pinned WordPress version.

Block save output changes between WordPress releases. When a block's markup no
longer matches what its save function produces, the editor shows "Attempt Block
Recovery" — a broken block the client cannot fix. That is why this file is tied
to one version, and why it has to be rechecked when the pin moves.

WordPress 7.2 is due around December 2026 and brings Twenty Twenty-Seven, so
plan on doing this then.

### The procedure

1. Stand up a site on the new version with the pinned theme.
2. Upload one image to the media library. Cover, Image and Media & Text all
   embed a real attachment ID and cannot be checked without one. Delete it
   afterwards.
3. For each approved block, in this order — most attributes first, since those
   drift most:

   Cover, Media & Text, Image, Group with background, Group with grid layout,
   Columns, Buttons, Details, Quote, Table, Heading, Paragraph, List, Spacer,
   Separator.

   Build it in the editor with the attributes shown in this file, open the
   block's options menu, choose **Copy**, and compare the clipboard against
   what is written here.
4. **Where they differ, the editor is right.** Update this file.
5. One block at a time. Batching is how a wrong correction gets written and not
   noticed.

Budget about an hour. When finished, update the version line at the top of this
file and bump the plugin version.

### Promoting a candidate block

Same procedure: build it, copy it, capture the real markup, then move it out of
Candidates into the approved sections above with notes on its required
attributes.
