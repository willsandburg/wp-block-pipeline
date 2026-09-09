# Publishing notes

Not part of the plugin. Delete before publishing, or keep it out of the repo.

## Repo layout

This whole folder is the marketplace. Push it to a public GitHub repo named
`wp-block-pipeline` under your account, and the install command in README.md
works as written.

```
wp-block-pipeline/                      ← the GitHub repo
├── .claude-plugin/
│   └── marketplace.json                ← the catalog
├── plugins/
│   └── wp-block-pipeline/
│       ├── .claude-plugin/
│       │   └── plugin.json             ← the manifest
│       ├── commands/                   ← /wp-start, /wp-push
│       └── skills/
│           └── wp-block-pipeline/
│               ├── SKILL.md
│               └── references/
└── README.md
```

The marketplace name and the plugin name are both `wp-block-pipeline`, which is
why the install line reads `wp-block-pipeline@wp-block-pipeline`. Rename either
in the JSON if you want them different.

## Test locally before pushing

```
/plugin marketplace add /full/path/to/wp-block-pipeline
/plugin install wp-block-pipeline@wp-block-pipeline
```

A local path works the same as a GitHub repo. Restart Claude Code, then check
`/wp-start` appears.

## Things to verify

**Asset paths.** `/wp-start` copies files out of `references/assets/`. When
installed from a marketplace the plugin lives in
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, not in your project.
Confirm the command finds the assets from there. There are open reports of
skill and asset resolution inside plugin caches not always following the
expected path, so test the marketplace install specifically, not just the local
path install.

**The skill `name` field.** `SKILL.md` sets `name: wp-block-pipeline`
explicitly. Leave it. Without it, Claude Code falls back to the install
directory name, which for marketplace installs is a version string that changes
on every update.

**Command name collisions.** `/wp-start` is generic enough that another plugin
could claim it. If that happens, commands can be invoked namespaced as
`/wp-block-pipeline:wp-start`.

## Versioning

Bump `version` in both `.claude-plugin/marketplace.json` and
`plugins/wp-block-pipeline/.claude-plugin/plugin.json` together. Users get
updates through `/plugin update`.

## Before selling this

Everything here is readable markdown. There is no licensing, no token, and no
way to add one that survives someone forwarding the folder — a plugin is files.

If you want recurring revenue rather than a one-time sale, the skills stay on
your server and the plugin becomes a thin client that talks to it. Same content,
different business. Decide which before the first customer, because you cannot
un-send files.
