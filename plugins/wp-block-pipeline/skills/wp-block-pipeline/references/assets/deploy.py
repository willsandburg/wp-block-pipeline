#!/usr/bin/env python3
"""
Push a generated site to a target WordPress install.

    python3 deploy.py site/site.live.json          # push
    python3 deploy.py site/site.live.json --dry    # show what would happen

Why this exists: page markup embeds attachment IDs and absolute upload URLs, so
the same HTML cannot be pushed to two different sites unchanged. Media is
uploaded to the target first, then every reference in the markup is rewritten to
the target's own IDs and URLs before the pages go up. Skip that and the images
break and the Cover blocks fail validation.

Order is fixed and matters: styles, then media, then pages.
"""
import json, sys, os, subprocess, re, mimetypes

PAGES = [
    # file,           title,        slug,       menu_order, front page?
    ('home.html',     'Home',       'home',      1, True),
    ('output.html',   'The output', 'output',    2, False),
    ('services.html', 'Services',   'services',  3, False),
    ('pricing.html',  'Pricing',    'pricing',   4, False),
    ('about.html',    'About',      'about',     5, False),
    ('contact.html',  'Contact',    'contact',   6, False),
]

def api(cfg, method, path, data=None, headers=None, binary=None):
    args = ['curl', '-s', '-w', '\n%{http_code}', '-X', method,
            cfg['url'].rstrip('/') + path, '-u', f"{cfg['user']}:{cfg['app_password']}"]
    for h in (headers or []): args += ['-H', h]
    if binary: args += ['--data-binary', '@' + binary]
    elif data is not None: args += ['-H', 'Content-Type: application/json', '-d', json.dumps(data)]
    out = subprocess.run(args, capture_output=True, text=True).stdout
    body, code = out.rsplit('\n', 1)
    return code.strip(), (json.loads(body) if body.strip().startswith(('{', '[')) else body)

def rewrite_media(html, local_media, live_media, local_url=None, live_url=None):
    """Swap local attachment IDs and upload URLs for the target's own.

    Two passes via placeholders, because a local id can collide with a live id
    (local 8 -> live 12 while local 12 also exists) and naive sequential
    replacement would corrupt it.
    """
    for i, (fn, loc) in enumerate(local_media.items()):
        if fn not in live_media: continue
        tok = f'@@M{i}@@'
        html = html.replace(loc['source_url'], tok + 'URL')
        html = html.replace(f'"id":{loc["id"]},', f'"id":{tok},')
        html = html.replace(f'"mediaId":{loc["id"]},', f'"mediaId":{tok},')
        html = html.replace(f'wp-image-{loc["id"]}"', f'wp-image-{tok}"')
    for i, (fn, loc) in enumerate(local_media.items()):
        if fn not in live_media: continue
        tok, new = f'@@M{i}@@', live_media[fn]
        html = html.replace(tok + 'URL', new['source_url'])
        html = html.replace(tok, str(new['id']))
    # internal links (page hrefs) still point at the source site. Do this AFTER
    # the media swap, so upload URLs are already correct and are not touched.
    if local_url and live_url:
        html = html.replace(local_url.rstrip('/'), live_url.rstrip('/'))
    return html

def main(cfg_path, dry=False):
    cfg = json.load(open(cfg_path))
    local = json.load(open('site/site.json'))
    cfg.setdefault('media', {}); cfg.setdefault('pages', {})
    say = lambda m: print('  ' + m)
    print(f"\n== target: {cfg['url']}  {'(DRY RUN)' if dry else ''}\n")

    # 1 ---------------------------------------------------------- global styles
    gs = cfg.get('global_styles_id')
    if not gs:
        print("  ! No global_styles_id. Open the Site Editor on the target, change any\n"
              "    style, save, then re-run connect.sh. It cannot be created from outside.")
        return 1
    if not dry:
        code, _ = api(cfg, 'POST', f'/wp-json/wp/v2/global-styles/{gs}',
                      data=json.load(open('site/styles.json')))
        say(f'styles -> HTTP {code}')
    else: say(f'would push styles to global-styles/{gs}')

    # 2 ----------------------------------------------------------------- media
    for fn in local.get('media', {}):
        path = os.path.join('site/media', fn)
        if not os.path.exists(path): say(f'! missing {path}'); continue
        if fn in cfg['media']: say(f'media {fn} already on target (id {cfg["media"][fn]["id"]})'); continue
        if dry: say(f'would upload {fn}'); continue
        mime = mimetypes.guess_type(fn)[0] or 'application/octet-stream'
        code, d = api(cfg, 'POST', '/wp-json/wp/v2/media',
                      headers=[f'Content-Disposition: attachment; filename={fn}',
                               f'Content-Type: {mime}'], binary=path)
        if code != '201': say(f'! upload {fn} failed: {code} {str(d)[:120]}'); return 1
        cfg['media'][fn] = {'id': d['id'], 'source_url': d['source_url']}
        # carry the alt text across from the source site
        alt = local['media'][fn].get('alt')
        if alt: api(cfg, 'POST', f'/wp-json/wp/v2/media/{d["id"]}', data={'alt_text': alt})
        say(f'uploaded {fn} -> id {d["id"]}')
        json.dump(cfg, open(cfg_path, 'w'), indent=2)

    # 3 ----------------------------------------------------------------- pages
    front = None
    for fn, title, slug, order, is_front in PAGES:
        src = os.path.join('site/pages', fn)
        if not os.path.exists(src): say(f'! missing {src}'); continue
        html = rewrite_media(open(src).read(), local.get('media', {}), cfg['media'],
                             local.get('url'), cfg.get('url'))
        if dry:
            say(f'would push {title} ({slug}), {html.count("<!-- wp:")} blocks'); continue
        body = {'title': title, 'slug': slug, 'status': 'publish',
                'template': 'page-no-title', 'menu_order': order, 'content': html}
        if fn in cfg['pages']:
            code, d = api(cfg, 'POST', f'/wp-json/wp/v2/pages/{cfg["pages"][fn]}', data=body)
        else:
            code, d = api(cfg, 'POST', '/wp-json/wp/v2/pages', data=body)
        if code not in ('200', '201'): say(f'! {title} failed: {code} {str(d)[:140]}'); return 1
        cfg['pages'][fn] = d['id']
        if is_front: front = d['id']
        say(f'{title:<12} -> id {d["id"]}')
        json.dump(cfg, open(cfg_path, 'w'), indent=2)

    # 4 -------------------------------------------------------------- settings
    if not dry:
        s = {'title': 'Highland Sites'}
        if front: s.update({'show_on_front': 'page', 'page_on_front': front})
        for key, fnm in (('site_logo', 'logo-mark.png'), ('site_icon', 'favicon.png')):
            if fnm in cfg['media']: s[key] = cfg['media'][fnm]['id']
        code, _ = api(cfg, 'POST', '/wp-json/wp/v2/settings', data=s)
        say(f'settings (title, front page, logo, icon) -> HTTP {code}')

    if not dry:
        json.dump(cfg, open(cfg_path, 'w'), indent=2)
        print(f"\n  Wrote {cfg_path}. Never delete it - those IDs are the only record\n"
              f"  of what is on the target.")
    return 0

if __name__ == '__main__':
    if len(sys.argv) < 2: print(__doc__); sys.exit(2)
    sys.exit(main(sys.argv[1], '--dry' in sys.argv))
