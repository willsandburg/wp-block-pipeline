# Design on the block pipeline

Read this before any layout work on a WordPress block site.

`design-toolkit.md` is the React path's design doc. Three of its four tools —
21st.dev, shadcn, scroll-craft — are React-only and do not apply here. What
does apply is the standard those tools exist to meet, and it applies harder,
because on this path there is no component library doing any of the work for
you. Core blocks are deliberately neutral. Everything that makes the site look
like somebody good built it comes from decisions made in `styles.json` and from
how blocks are composed.

**Generic is a failure state.** Every site needs one thing a visitor will
remember. Decide what that is during the interview, before any block exists.

---

## Where the design actually happens

On the React path, design lives in components. Here it lives in three places,
in order of leverage:

**1. The global styles object.** Palette, type scale, spacing scale, per-block
defaults. This does most of the work. A well-built styles object makes plain
core blocks look intentional; a weak one makes them look like a default install.
Spend the time here. See [global-styles.md](global-styles.md).

**2. Composition.** Which blocks, nested how, in what rhythm. A hero is a Cover
containing a Heading, a Paragraph and Buttons — the design is in the proportions,
the spacing and the restraint, not in the block choice.

**3. Content.** Real copy at real length. A page laid out around three-word
placeholder headings falls apart the moment real sentences arrive.

There is no fourth place. If a design idea cannot be expressed through those
three, it is a request to add a block, not a reason to reach for custom CSS.
See the rule in [allowed-blocks.md](allowed-blocks.md).

---

## Working within the constraint

The approved block list is short on purpose. That is a design constraint, and
constraints tend to produce better work than infinite options. But it does mean
composing rather than reaching.

**Rhythm over variety.** A page that alternates between two or three section
shapes with confident spacing reads better than one that uses every block
available. Repetition is not a weakness.

**Vary the density, not the components.** A generous full-bleed section
followed by a tight grid followed by a wide quote creates pace using the same
handful of blocks.

**Let one thing be big.** Most generated pages are uniformly medium. Pick one
element per page — a headline, an image, a number — and let it be genuinely
large. This single decision separates most designed pages from most generated
ones.

**Asymmetry is available.** Media & Text and unequal Columns both break the
centred-everything default that makes generated sites recognisable.

**Whitespace is the cheapest upgrade.** The spacing scale goes up to a clamped
8rem. Most generated pages never use the top of the scale, and look cramped as
a result.

---

## Typography carries more weight here

With no component library, type is doing more of the work. Two families
maximum, one display face with personality and one refined body face.

**Avoid Inter, Roboto, Arial, `system-ui` and Space Grotesk.** Ubiquitous, and
they read as a non-decision.

A fluid scale with `clamp()`, not fixed sizes. Line height around 1.6 for body,
1.15 for headings. Content width around 42rem so line length stays readable.

---

## Colour

Six roles and one accent. **Never pure black.** Tint secondary text rather than
flattening it to grey.

The accent should appear rarely. A colour used on every third element is not an
accent, it is a second primary, and the page loses its focal points.

---

## The refuse list

These mark a page as machine-made regardless of stack. Do not ship them.

- Identical three-across feature-card grids
- `01 / 06` section counters and "scroll to explore" nudges
- Gradient text, and AI-purple gradients generally
- Invented statistics and fake dashboard screenshots
- The cream-and-brass palette every craft brand defaults to
- Body text below 4.5:1 contrast against what is actually behind it
- A headline that wraps to six lines on a phone

Additions specific to this path:

- **A page that is a stack of full-width centred Groups.** The default shape of
  a generated block page, and instantly recognisable.
- **Spacer blocks doing the spacing.** Fixed heights that do not respond to
  screen width. Use `blockGap` and group padding.
- **Hardcoded pixel values in block markup.** Breaks the design system and
  cannot be changed by the client.
- **Cover blocks at low `dimRatio` over busy photos.** Looks fine on the
  mockup, fails contrast in reality.
- **Everything at `wideSize`.** If nothing is ever at content width, nothing is
  ever wide. The contrast is the point.
- **Twenty Twenty-Five's demo content or its style variations.** If the site
  could be mistaken for another Twenty Twenty-Five site, start over on the
  styles object.

---

## Mobile is not a checkpoint

Most of a generated page's mobile behaviour is decided when the markup is
written, not when someone checks it at the end. Get these right and 375px
usually just works; get them wrong and no amount of later fiddling fixes it.

**Grids: `minimumColumnWidth`, never `columnCount`.** A grid with
`"columnCount":3` stays three columns and crushes its contents. A grid with
`"minimumColumnWidth":"17rem"` chooses its own column count from the space
available and reflows to one column on a phone with no breakpoint logic at all.

**Let Columns stack.** They stack by default. `"isStackedOnMobile":false` is
almost always wrong — reach for it only when two columns are genuinely a single
unit, like a small label beside a value.

**Media & Text keeps `is-stacked-on-mobile`.** It is in the default markup for a
reason. Hand-building the same layout out of Columns loses it.

**Cap the top of the type scale, and cap it harder for monospace.** A heading
that is fine at `4rem` on a desktop wraps to six lines on a phone, which is on
the refuse list. Monospace runs roughly a third wider per character than a
proportional face at the same size, so a mono display face needs a lower clamp
maximum and negative tracking, not the same numbers.

**Test the longest real heading, not the placeholder.** A design that only holds
with the exact copy generated breaks the first time the client edits it.

**Cover heights in `vh`, never `px`.** A fixed pixel height is a different
proportion of every screen. Note that a Cover crops harder as the viewport
narrows: a 3:2 image in a tall narrow container loses its sides, so check the
subject still survives the crop rather than assuming the composition holds.

**Centre hero content.** Left-aligned hero text inside a narrow column reads as
misaligned rather than deliberate on a phone, especially under a centred logo
and nav.

**Never space with Spacer blocks.** Fixed heights do not respond to screen
width. Use `blockGap` and group padding, both of which come off the fluid
scale.

---

## The client is going to edit this

A design that only works with the exact copy generated is a design that breaks
in week two. Before shipping:

- Would this hold if the headline were twice as long?
- Would this hold with four items instead of three?
- If the client swaps the hero image, does the text still pass contrast?
- Is anything relying on an exact character count?

Where the answer is no, either fix the composition or lock that section
`contentOnly` and say so in the handover.

---

## Accessibility is not a separate pass

- Body text at 4.5:1 against its **actual** background, which for a Cover block
  means the image plus the overlay
- One `h1` per page, no skipped levels
- Alt text on every image, `alt=""` on decorative ones
- Buttons that read as buttons without relying on colour alone
- Every page checked at 375px, 768px and 1440px

Core blocks give you reasonable semantics for free. Do not undo that by using a
Table for layout or a Paragraph where a Heading belongs.
