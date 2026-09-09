# Global styles

The design system for a generated site. Palette, typography, spacing and
per-block defaults, written once per site and inherited by every block on it.

This is the file that decides whether the site looks designed or looks like a
default WordPress install with different colours. Core blocks are neutral. What
you put here is the design.

---

## Where it lives

Global styles are stored in the database, in the `wp_global_styles` post type,
which is where the Site Editor already keeps a site's customizations. Bootstrap
reads the post ID and records it in `site.json` as `global_styles_id`.

**Nothing is written to the filesystem.** No theme files, no `theme.json` on
disk, no PHP. The plugin only ever touches the database, which is what makes it
safe to install on a client's host.

The JSON shape is the same as `theme.json`'s, minus the top-level metadata. It
layers on top of Twenty Twenty-Five's own `theme.json` rather than replacing
it, so anything left out falls back to the theme's value.

---

## The shape

```json
{
  "settings": {
    "color": {
      "palette": [
        { "slug": "base",     "color": "#FBFAF7", "name": "Base" },
        { "slug": "contrast", "color": "#1A1917", "name": "Contrast" },
        { "slug": "primary",  "color": "#2F4A3C", "name": "Primary" },
        { "slug": "secondary","color": "#6B7F74", "name": "Secondary" },
        { "slug": "tertiary", "color": "#EDEAE3", "name": "Tertiary" },
        { "slug": "accent",   "color": "#C05A2E", "name": "Accent" }
      ]
    },
    "typography": {
      "fontFamilies": [
        {
          "slug": "display",
          "name": "Display",
          "fontFamily": "\"Fraunces\", Georgia, serif",
          "fontFace": [
            {
              "fontFamily": "Fraunces",
              "fontWeight": "400 700",
              "fontStyle": "normal",
              "fontStretch": "normal",
              "src": [ "file:./assets/fonts/fraunces.woff2" ]
            }
          ]
        },
        {
          "slug": "body",
          "name": "Body",
          "fontFamily": "\"Karla\", -apple-system, sans-serif"
        }
      ],
      "fontSizes": [
        { "slug": "small",   "size": "0.875rem", "name": "Small" },
        { "slug": "medium",  "size": "1.0625rem", "name": "Medium" },
        { "slug": "large",   "size": "clamp(1.25rem, 1.1rem + 0.75vw, 1.5rem)", "name": "Large" },
        { "slug": "x-large", "size": "clamp(1.75rem, 1.4rem + 1.75vw, 2.5rem)", "name": "Extra large" },
        { "slug": "xx-large","size": "clamp(2.5rem, 1.8rem + 3.5vw, 4rem)", "name": "Huge" }
      ]
    },
    "spacing": {
      "spacingSizes": [
        { "slug": "20", "size": "0.5rem",  "name": "1" },
        { "slug": "30", "size": "1rem",    "name": "2" },
        { "slug": "40", "size": "1.5rem",  "name": "3" },
        { "slug": "50", "size": "2.5rem",  "name": "4" },
        { "slug": "60", "size": "clamp(3rem, 2rem + 5vw, 5rem)", "name": "5" },
        { "slug": "70", "size": "clamp(4rem, 2.5rem + 7.5vw, 8rem)", "name": "6" }
      ]
    },
    "layout": {
      "contentSize": "42rem",
      "wideSize": "76rem"
    }
  },
  "styles": {
    "color": {
      "background": "var(--wp--preset--color--base)",
      "text": "var(--wp--preset--color--contrast)"
    },
    "typography": {
      "fontFamily": "var(--wp--preset--font-family--body)",
      "fontSize": "var(--wp--preset--font-size--medium)",
      "lineHeight": "1.6"
    },
    "spacing": {
      "blockGap": "var(--wp--preset--spacing--40)"
    },
    "elements": {
      "heading": {
        "typography": {
          "fontFamily": "var(--wp--preset--font-family--display)",
          "fontWeight": "600",
          "lineHeight": "1.15"
        }
      },
      "h1": { "typography": { "fontSize": "var(--wp--preset--font-size--xx-large)" } },
      "h2": { "typography": { "fontSize": "var(--wp--preset--font-size--x-large)" } },
      "h3": { "typography": { "fontSize": "var(--wp--preset--font-size--large)" } },
      "link": {
        "color": { "text": "var(--wp--preset--color--primary)" },
        ":hover": { "typography": { "textDecoration": "underline" } }
      },
      "button": {
        "color": {
          "background": "var(--wp--preset--color--accent)",
          "text": "var(--wp--preset--color--base)"
        },
        "typography": {
          "fontFamily": "var(--wp--preset--font-family--body)",
          "fontWeight": "600",
          "fontSize": "var(--wp--preset--font-size--medium)"
        },
        "spacing": {
          "padding": { "top": "0.9rem", "bottom": "0.9rem", "left": "1.75rem", "right": "1.75rem" }
        },
        "border": { "radius": "2px" },
        ":hover": {
          "color": { "background": "var(--wp--preset--color--primary)" }
        }
      }
    },
    "blocks": {
      "core/quote": {
        "typography": {
          "fontFamily": "var(--wp--preset--font-family--display)",
          "fontSize": "var(--wp--preset--font-size--large)",
          "fontStyle": "normal"
        },
        "border": {
          "left": { "width": "3px", "style": "solid", "color": "var(--wp--preset--color--accent)" }
        },
        "spacing": { "padding": { "left": "var(--wp--preset--spacing--40)" } }
      },
      "core/separator": {
        "color": { "text": "var(--wp--preset--color--tertiary)" }
      }
    }
  }
}
```

The values above are an example, not a template to reuse. Derive real ones from
the brand kit in `resources/design/`, or from the interview answers if there is
no brand kit.

---

## The two syntaxes

Inside `styles`, reference presets as full CSS custom properties:

```json
"fontSize": "var(--wp--preset--font-size--large)"
```

Inside block markup, the same value is written in the shorthand form in the
JSON and the full form in the style attribute, and both must be present:

```html
<!-- wp:group {"style":{"spacing":{"padding":{"top":"var:preset|spacing|60"}}}} -->
<div class="wp-block-group" style="padding-top:var(--wp--preset--spacing--60)">
```

Mixing these up is the most common cause of a block that looks right in the
markup and fails validation in the editor.

---

## Rules

### Six colour roles and one accent

`base`, `contrast`, `primary`, `secondary`, `tertiary`, `accent`. Six is
enough for any marketing site, and a longer palette produces inconsistency
rather than range.

**Never pure black or pure white.** `#000000` on `#FFFFFF` is harsh and reads as
a non-decision. Warm or cool the neutrals slightly.

**Tint secondary text rather than greying it.** Secondary text should be a
desaturated version of a palette colour, not `#888888`.

Keep the slugs exactly as named. Block markup references them by slug, and
`allowed-blocks.md` assumes these six exist.

### Two font families, maximum

One display face for headings with actual personality, one refined face for
body. Never more.

**Avoid Inter, Roboto, Arial, `system-ui` and Space Grotesk.** They are
ubiquitous and read as a non-decision. This rule carries over from
`design-toolkit.md` unchanged, and it matters more here, not less, because
typography is doing more of the work when the blocks are plain.

Self-host through `fontFace` with a `file:./` path rather than loading from
Google's CDN. Better performance, and it does not put a third-party request on
a client's site.

### A fluid type scale, not fixed sizes

Use `clamp()` for anything above body size. A heading at a fixed `4rem` wraps to
six lines on a phone, which is on the refuse list.

Five sizes is enough. More produces inconsistency.

### A spacing scale, used everywhere

Six steps, referenced by slug from every block. **Never hardcode a pixel value
in block markup.** Hardcoded spacing cannot be changed by the client, does not
respond to screen width, and ignores the scale.

Set `blockGap` in `styles.spacing`. It handles most of the vertical rhythm on
its own, which is why Spacer blocks are rarely needed.

### Style blocks, not instances

Anything true of every Quote on the site belongs in `styles.blocks`, not
repeated on each Quote in the markup. Same for buttons, links and headings.

This is what makes the site editable later. A client who wants all buttons a
different colour changes one thing in the Site Editor. If the colour was baked
into forty button blocks, they cannot.

### Set `contentSize` and `wideSize` deliberately

`contentSize` is the reading width. Around 42rem keeps line length in the range
that is comfortable to read. `wideSize` is what a wide-aligned block expands to.

These two numbers do more for how a page feels than most colour decisions.

---

## Style variations

Twenty Twenty-Five ships with style variations of its own. Ignore them. Generate
a full styles object rather than layering onto a variation, so what the site
looks like is fully determined by `styles.json` and not by which variation
happened to be active.

---

## Responsive styles (WordPress 7.1+)

Spacing and typography can now be set per breakpoint from Global Styles, and a
block theme can define its own mobile and tablet breakpoints rather than using
the WordPress defaults.

**Keep the fluid `clamp()` scale as the base.** It handles the majority of
cases with no breakpoint logic and degrades gracefully at any width. Reach for
explicit responsive values only where fluid scaling genuinely cannot express
what is needed — a grid that must go one-column below a specific width, a
heading that needs different tracking on mobile.

The failure mode to avoid is rebuilding a fixed breakpoint system on top of a
fluid one. Then you have two systems disagreeing with each other and neither is
the source of truth.

If you do set custom breakpoints, record them in the project `CLAUDE.md`.
Future sessions cannot infer them from the styles object alone.

---

## Interaction states (WordPress 7.1+)

Supported blocks including Button and Navigation Link carry distinct styles for
`:hover`, `:focus`, `:focus-visible` and `:active`, set in the styles object
with no custom CSS.

The button and link examples above already use `:hover`. Add `:focus-visible`
to both — keyboard users need a visible focus ring, and this is now the
supported way to provide one rather than an escape-hatch use of custom CSS:

```json
":focus-visible": {
  "outline": {
    "width": "2px",
    "style": "solid",
    "color": "var(--wp--preset--color--accent)",
    "offset": "2px"
  }
}
```

---

## A specificity change to watch for

In WordPress 7.1, block-level preset classes match root-level specificity.

This does not require any change to how the styles object is written, but it
can change which rule wins when a block-level value and a root-level value
disagree. It produces no error — the page simply renders differently than it
did on 7.0.

If a site upgrades WordPress and something looks subtly off with no obvious
cause, check this first.

---

## Custom CSS

Global styles supports a `css` property, at the top level and per block. It is
an escape hatch and it is **not to be used to work around a missing block**.
That case is covered by the rule in `allowed-blocks.md` and the answer is to
refuse and add the block.

Legitimate uses are now narrower than they were. `:focus-visible` moved into
the native state selectors above and should be set there instead. What is left:
`prefers-reduced-motion` rules, print styles, and the occasional selector the
styles object genuinely cannot express.

If custom CSS is doing layout, something has gone wrong.

---

## Verify before moving on

Push the styles object, then load the site and check:

- Headings and body are the two intended faces, and neither has fallen back
- Body text hits 4.5:1 against the actual background
- The page holds up at 375px — no heading wrapping to six lines
- Buttons look like buttons and links look like links
- The site does not look like the Twenty Twenty-Five demo

The last one is the real test. If a stranger could not tell this apart from any
other Twenty Twenty-Five site, the styles object has not done its job yet.
