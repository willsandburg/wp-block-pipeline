---
description: Run the block verification pass — check every approved block's markup against the running WordPress version and fix the reference file.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Block verification pass

The markup in `references/allowed-blocks.md` was written from documented save
output, not captured from a running install. WordPress 7.1 alone brought roughly
600 block editor changes over 7.0. Some of what is in that file is wrong, and a
block whose markup fails validation shows the client "Attempt Block Recovery" on
a page they cannot fix.

This pass fixes that. It takes about an hour and is done once per pinned
WordPress version.

## What to do

1. Read `references/allowed-blocks.md` and list every approved block.

2. Confirm a site is running and tell me its WordPress version. The pass is only
   valid against one version, so record which.

3. Work through the blocks **one at a time**, in this order — most attributes
   first, since those are most likely to have drifted:

   Cover, Media & Text, Image, Group with background, Group with grid layout,
   Columns, Buttons, Details, Quote, Table, Heading, Paragraph, List, Spacer,
   Separator.

   For each one, tell me exactly what to build in the editor, with the specific
   attributes from the reference file. Then ask me to use the block's Copy
   option and paste the result back to you.

4. Compare what I paste against the file. **Where they differ, the editor is
   right.** Update the file to match, and note what changed.

5. Do not batch. One block, one comparison, one fix. Batching is how a wrong
   correction gets written and not noticed.

## When done

- Remove the "not captured from a running install" warning near the top of
  `references/allowed-blocks.md`.
- Replace it with the version it was verified against and today's date.
- Summarise which blocks changed and how.

## Candidates

If I want to promote a candidate block (Tabs, or anything else in that section)
to the approved list, use the same procedure: build it, copy it, capture the
real markup, then move it out of Candidates.

For Tabs specifically, answer this first: does `templateLock: contentOnly` on a
parent group still allow editing text inside a tab panel? If not, the block does
not fit the handoff model and should not be approved regardless of how useful it
looks.
