#!/usr/bin/env python3
"""
Mechanical checks for generated pages. Run before pushing, and again in Phase 7.

Most of Phase 7 needs no browser. This catches what reading the page cannot:
markup that renders perfectly on the front end and fails validation the moment
the client opens the editor.

    python3 audit.py site/pages site/site.json site/styles.json

Exit code is the number of problems found, so it works in a pre-push hook.
"""
import json, re, sys, glob, os

APPROVED = {
    'core/group','core/columns','core/column','core/spacer','core/separator',
    'core/paragraph','core/heading','core/list','core/list-item','core/image',
    'core/buttons','core/button','core/quote','core/cover','core/media-text',
    'core/details','core/table','highlandsites/form',
}
BANNED = {'core/html','core/shortcode'}

# Attributes that never render into markup, so they can never break validation.
UNIVERSAL = {'metadata','lock','templateLock','className','style','anchor'}

# Attributes each block is documented to accept. Anything else is unverified —
# which is how dimRatio:55 shipped to five page headers undetected.
ATTRS = {
    'core/cover':      {'url','id','dimRatio','isDark','align','layout','minHeight','minHeightUnit'},
    'core/group':      {'align','backgroundColor','textColor','layout'},
    'core/heading':    {'level','textAlign','textColor','fontSize'},
    'core/paragraph':  {'align','textColor','fontSize'},
    'core/image':      {'id','sizeSlug','linkDestination','align'},
    'core/media-text': {'align','mediaId','mediaType','mediaPosition'},
    'core/columns':    {'align','isStackedOnMobile'},
    'core/column':     {'width'},
    'core/buttons':    {'layout'},
    'core/button':     set(),
    'core/details':    {'showContent'},
    'core/list':       {'ordered'},
    'core/list-item':  set(),
    'core/separator':  set(),
    'core/spacer':     {'height'},
    'core/quote':      set(),
    'core/table':      set(),
    'highlandsites/form': {'formId','submitLabel','successMessage','recipient','align'},
}

def dim_class(ratio):
    """What core's Cover save() puts on the overlay span for a given dimRatio."""
    if ratio == 0 or ratio == 50:
        return None
    return 'has-background-dim-%d' % (10 * round(ratio / 10))

def audit(pages_dir, site_json, styles_json):
    cfg = json.load(open(site_json))
    palette = {e['slug'] for e in json.load(open(styles_json))['settings']['color']['palette']}
    media_ids = {v['id'] for v in cfg.get('media', {}).values()}
    problems = []

    for path in sorted(glob.glob(os.path.join(pages_dir, '*.html'))):
        name = os.path.basename(path)
        if name.startswith('_'):
            continue
        s = open(path).read()
        def bad(msg): problems.append('%s: %s' % (name, msg))

        # --- blocks ------------------------------------------------------
        used = {(b if '/' in b else 'core/' + b)
                for b in re.findall(r'<!-- wp:([a-z0-9-]+/[a-z0-9-]+|[a-z0-9-]+)', s)}
        for b in sorted(used & BANNED):   bad('banned block %s' % b)
        for b in sorted(used - APPROVED - BANNED): bad('unapproved block %s' % b)

        # --- attributes --------------------------------------------------
        for m in re.finditer(r'<!-- wp:([a-z0-9-]+/[a-z0-9-]+|[a-z0-9-]+) (\{.*?\}) (?:/)?-->', s):
            blk = m.group(1) if '/' in m.group(1) else 'core/' + m.group(1)
            try: attrs = json.loads(m.group(2))
            except Exception as e:
                bad('malformed block JSON on %s: %s' % (blk, e)); continue
            known = ATTRS.get(blk)
            if known is None: continue
            for k in attrs:
                if k not in known and k not in UNIVERSAL:
                    bad('%s has undocumented attribute "%s"' % (blk, k))

            # dimRatio is the one that renders fine and fails in the editor
            if blk == 'core/cover' and 'dimRatio' in attrs:
                need = dim_class(attrs['dimRatio'])
                after = s[m.end():m.end() + 400]
                if need and need not in after:
                    bad('cover dimRatio %s needs class "%s" on the overlay span'
                        % (attrs['dimRatio'], need))
                if not need and re.search(r'has-background-dim-\d+', after):
                    bad('cover dimRatio %s must NOT carry a level class' % attrs['dimRatio'])

        # --- structure ---------------------------------------------------
        levels = [int(x) for x in re.findall(r'<h([1-6])[ >]', s)]
        if levels.count(1) != 1: bad('%d h1 elements' % levels.count(1))
        for a, b in zip(levels, levels[1:]):
            if b > a + 1: bad('heading level skip h%d -> h%d' % (a, b))

        for img in re.findall(r'<img [^>]*>', s):
            if 'alt=' not in img: bad('img without alt attribute')

        # --- design system ------------------------------------------------
        px = re.findall(r'(?<!min-height:)(?<!flex-basis:)\b\d+px\b', s)
        if px: bad('hardcoded px: %s' % sorted(set(px)))
        hexes = re.findall(r'#[0-9A-Fa-f]{6}\b', s)
        if hexes: bad('raw hex colour: %s' % sorted(set(hexes)))

        j = set(re.findall(r'var:preset\|spacing\|(\d+)', s))
        c = set(re.findall(r'var\(--wp--preset--spacing--(\d+)\)', s))
        if j != c: bad('spacing preset syntaxes disagree: %s' % sorted(j ^ c))

        for slug in set(re.findall(r'"(?:backgroundColor|textColor)":"([a-z-]+)"', s)) - palette:
            bad('colour slug "%s" is not in the palette' % slug)

        for i in {int(x) for x in re.findall(r'"(?:id|mediaId)":(\d+)', s)} - media_ids:
            bad('attachment id %d is not in the media library' % i)

        print('  %-18s %s' % (name, 'PASS' if not [p for p in problems if p.startswith(name)] else 'FAIL'))

    print()
    if problems:
        print('%d problem(s):' % len(problems))
        for p in problems: print('  x %s' % p)
    else:
        print('All checks passed.')
    return len(problems)

def audit_live(url):
    """Fetch a rendered page and check what page files cannot show.

    The page audit reads site/pages/*.html. Header and footer are template
    parts, so a stock block theme's demo navigation - eight links pointing at
    "#" - passes every file-level check and ships.
    """
    import urllib.request
    print('\n== live checks: %s' % url)
    try:
        html = urllib.request.urlopen(url, timeout=25).read().decode('utf-8', 'replace')
    except Exception as e:
        print('  ! could not fetch: %s' % e); return 1
    problems = []
    dead = html.count('href="#"')
    if dead: problems.append('%d dead href="#" link(s) - most likely the theme\'s demo navigation' % dead)
    for demo in ('Twenty Twenty-Five', 'Twenty Twenty-Four', 'My WordPress Website'):
        if demo in html: problems.append('theme demo string still present: "%s"' % demo)
    for stale in ('127.0.0.1', '.loc/', 'localhost:'):
        if stale in html: problems.append('reference to the build environment: %s' % stale)
    imgs = set(re.findall(r'src="(https?://[^"]+\.(?:webp|png|jpe?g))"', html))
    for u in sorted(imgs)[:12]:
        try:
            code = urllib.request.urlopen(u, timeout=15).status
            if code != 200: problems.append('image %s -> HTTP %s' % (u.rsplit("/",1)[-1], code))
        except Exception:
            problems.append('image does not resolve: %s' % u.rsplit('/',1)[-1])
    if not problems: print('  %d images checked, no dead links, no demo content.' % len(imgs))
    for x in problems: print('  x %s' % x)
    return len(problems)

if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == '--live':
        sys.exit(audit_live(a[1]))
    sys.exit(audit(a[0] if a else 'site/pages',
                   a[1] if len(a) > 1 else 'site/site.json',
                   a[2] if len(a) > 2 else 'site/styles.json'))
