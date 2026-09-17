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
Page titles, order, site title, logo and icon come from site/pages/_pages.json;
a post's featured image from a "featured" filename in site/posts/_meta.json.
"""
import json, sys, os, subprocess, re, mimetypes

def load_manifest():
    """Page list, site title, logo and icon for this site.

    Read from site/pages/_pages.json so nothing site-specific lives in this
    script. Without the file, every page file not starting with "_" is pushed,
    home.html first as the front page, the rest in name order, titled from the
    filename.

        {
          "site_title": "Keep Bricks",
          "logo": "logo.png", "icon": "favicon.png",
          "pages": [
            {"file": "home.html", "title": "Home", "slug": "home", "front": true},
            {"file": "services.html", "title": "Services"}
          ]
        }

    slug defaults to the filename, menu_order to the list position.
    """
    path = 'site/pages/_pages.json'
    m = json.load(open(path)) if os.path.exists(path) else {}
    pages = m.get('pages') or [
        {'file': f} for f in sorted(os.listdir('site/pages'), key=lambda f: (f != 'home.html', f))
        if f.endswith('.html') and not f.startswith('_')]
    out = []
    for i, p in enumerate(pages, 1):
        stem = p['file'][:-5]
        out.append((p['file'], p.get('title') or stem.replace('-', ' ').title(),
                    p.get('slug') or stem, p.get('menu_order', i),
                    p.get('front', stem == 'home')))
    return m, out

def api(cfg, method, path, data=None, headers=None, binary=None):
    args = ['curl', '-s', '-w', '\n%{http_code}', '-X', method,
            cfg['url'].rstrip('/') + path, '-u', f"{cfg['user']}:{cfg['app_password']}"]
    for h in (headers or []): args += ['-H', h]
    if binary: args += ['--data-binary', '@' + binary]
    elif data is not None: args += ['-H', 'Content-Type: application/json', '-d', json.dumps(data)]
    out = subprocess.run(args, capture_output=True, text=True).stdout
    body, code = out.rsplit('\n', 1)
    if 'sgcaptcha' in body:
        # SiteGround's anti-bot answers 202 with a challenge page, so nothing
        # reached WordPress. Stop rather than report a 202 as if it worked.
        ip = re.search(r'ipc:([0-9a-f.:]+):', body)
        sys.exit(f"\n  ! SiteGround's bot captcha blocked this request"
                 f"{' from IP ' + ip.group(1) if ip else ''}. Nothing was changed.\n"
                 f"    Ask SiteGround support to whitelist that IP for the site, then re-run.")
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
        # match the class whether or not a size class follows it - an
        # "wp-image-8 size-full" left un-rewritten fails validation on the target
        html = re.sub(rf'wp-image-{loc["id"]}(?=[" ])', f'wp-image-{tok}', html)
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
    manifest, pages = load_manifest()
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
    for fn, title, slug, order, is_front in pages:
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

    # 3b ---------------------------------------------------------------- posts
    meta_path = 'site/posts/_meta.json'
    blog_id = None
    if os.path.exists(meta_path):
        cfg.setdefault('posts', {})
        for m in json.load(open(meta_path)):
            slug = m['slug']; src = os.path.join('site/posts', slug + '.html')
            if not os.path.exists(src): say('! missing %s' % src); continue
            html = rewrite_media(open(src).read(), local.get('media', {}), cfg['media'],
                                 local.get('url'), cfg.get('url'))
            if dry: say('would push post "%s"' % m['title']); continue
            body = {'title': m['title'], 'slug': slug, 'status': 'publish',
                    'content': html, 'excerpt': m['excerpt']}
            # featured image by filename, so it resolves to the target's own ID
            fn = m.get('featured')
            if fn and fn in cfg['media']: body['featured_media'] = cfg['media'][fn]['id']
            ep = ('/wp-json/wp/v2/posts/%s' % cfg['posts'][slug]) if slug in cfg['posts'] else '/wp-json/wp/v2/posts'
            code, d = api(cfg, 'POST', ep, data=body)
            if code not in ('200', '201'): say('! post %s failed: %s %s' % (slug, code, str(d)[:140])); return 1
            cfg['posts'][slug] = d['id']
            say('post %-38s -> id %s' % (m['title'][:38], d['id']))
            json.dump(cfg, open(cfg_path, 'w'), indent=2)

        # The Blog page carries no content. The theme's Blog Home template
        # renders the query loop, so no template-level markup is generated here.
        if not dry:
            body = {'title': 'Blog', 'slug': 'blog', 'status': 'publish',
                    'content': '', 'menu_order': len(pages) + 1}
            ep = ('/wp-json/wp/v2/pages/%s' % cfg['pages']['blog.html']) if 'blog.html' in cfg['pages'] else '/wp-json/wp/v2/pages'
            code, d = api(cfg, 'POST', ep, data=body)
            if code in ('200', '201'):
                cfg['pages']['blog.html'] = d['id']; blog_id = d['id']
                say('Blog page   -> id %s' % d['id'])

    # 4 -------------------------------------------------------------- settings
    if not dry:
        s = {}
        if manifest.get('site_title'): s['title'] = manifest['site_title']
        if front: s.update({'show_on_front': 'page', 'page_on_front': front})
        if blog_id: s['page_for_posts'] = blog_id
        for key, fnm in (('site_logo', manifest.get('logo')), ('site_icon', manifest.get('icon'))):
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
