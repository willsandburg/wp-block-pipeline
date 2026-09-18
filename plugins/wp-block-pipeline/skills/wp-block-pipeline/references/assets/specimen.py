#!/usr/bin/env python3
"""
Publish the style specimen — every text style, colour, button and layout on the
site, on one page, so the design system can be judged before any real page is
built.

    python3 specimen.py site/site.json            # publish or update it
    python3 specimen.py site/site.json --remove   # delete it before handover
    python3 specimen.py site/site.json --with-media img.jpg cover.jpg
                                                  # append the image section

The specimen's page ID is recorded under `specimen_page`, deliberately NOT under
`pages`. Anything in `pages` is site content: /wp-publish pushes it to the live
site, and the specimen must never ship. Keeping it in its own key also means
--remove can find it later, in a different session, without guessing.

Reads site/styles.json only to report which presets the specimen will exercise.
"""
import json, sys, os, subprocess, re

SPECIMEN_SLUG = 'style-specimen'
SPECIMEN_TITLE = 'Style specimen'


def api(cfg, method, path, data=None):
    args = ['curl', '-s', '-w', '\n%{http_code}', '-X', method,
            cfg['url'].rstrip('/') + path,
            '-u', f"{cfg['user']}:{cfg['app_password']}"]
    if data is not None:
        args += ['-H', 'Content-Type: application/json', '-d', json.dumps(data)]
    out = subprocess.run(args, capture_output=True, text=True).stdout
    body, code = out.rsplit('\n', 1)
    return code.strip(), (json.loads(body) if body.strip().startswith(('{', '[')) else body)


def save(cfg_path, cfg):
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=2)
        f.write('\n')


def find_specimen_html():
    """The specimen markup, preferring a copy the project has edited."""
    for p in ('site/pages/_style-specimen.html', 'style-specimen.html'):
        if os.path.exists(p):
            return p
    sys.exit("  ! style-specimen.html not found.\n"
             "    Copy it from the skill's references/assets/ into the project root.")


def add_media_section(html, media_map, image_file, cover_file):
    """Append the Image / Media & Text / Cover section with real attachment IDs."""
    path = 'style-specimen-media.html'
    if not os.path.exists(path):
        sys.exit("  ! style-specimen-media.html not found in the project root.")

    for name, f in (('image', image_file), ('cover', cover_file)):
        if f not in media_map:
            sys.exit(f"  ! {f} is not in site.json's media map. Push the media first.")

    extra = open(path).read()
    # strip the instruction comment so it never reaches the page content
    extra = re.sub(r'^\s*<!--.*?-->\s*', '', extra, count=1, flags=re.S)

    for key, f in (('IMAGE', image_file), ('COVER', cover_file)):
        entry = media_map[f]
        extra = extra.replace(f'__{key}_ID__', str(entry['id']))
        extra = extra.replace(f'__{key}_URL__', entry['source_url'])

    left = re.findall(r'__[A-Z_]+__', extra)
    if left:
        sys.exit(f"  ! unsubstituted placeholders remain: {sorted(set(left))}")

    return html.rstrip() + '\n\n' + extra


def main():
    args = [a for a in sys.argv[1:]]
    cfg_path = next((a for a in args if not a.startswith('--')), 'site/site.json')
    flags = [a for a in args if a.startswith('--')]
    rest = [a for a in args if not a.startswith('--')][1:]

    if not os.path.exists(cfg_path):
        sys.exit(f"  ! {cfg_path} not found. Connect the site first.")
    cfg = json.load(open(cfg_path))
    existing = cfg.get('specimen_page')

    if '--remove' in flags:
        if not existing:
            print('  No specimen recorded. Nothing to remove.')
            return
        code, body = api(cfg, 'DELETE', f'/wp-json/wp/v2/pages/{existing}?force=true')
        if code not in ('200', '404'):
            sys.exit(f"  ! could not delete page {existing} (HTTP {code})")
        cfg.pop('specimen_page', None)
        save(cfg_path, cfg)
        print(f"  Removed the specimen (page {existing}) and cleared it from {cfg_path}.")
        return

    html = open(find_specimen_html()).read()

    if '--with-media' in flags:
        if len(rest) < 2:
            sys.exit('  ! --with-media needs two filenames: an image and a cover image.')
        html = add_media_section(html, cfg.get('media', {}), rest[0], rest[1])

    payload = {'title': SPECIMEN_TITLE, 'slug': SPECIMEN_SLUG, 'status': 'publish',
               'template': 'page-no-title', 'content': html}

    code = body = None
    verb = 'Published'
    if existing:
        code, body = api(cfg, 'POST', f'/wp-json/wp/v2/pages/{existing}', payload)
        verb = 'Updated'
        if code == '404':          # someone deleted it in wp-admin
            existing, code, verb = None, None, 'Recreated'
    if not existing:
        code, body = api(cfg, 'POST', '/wp-json/wp/v2/pages', payload)

    if code not in ('200', '201'):
        sys.exit(f"  ! specimen push failed (HTTP {code}): "
                 f"{body.get('message') if isinstance(body, dict) else body}")

    cfg['specimen_page'] = body['id']
    save(cfg_path, cfg)

    print(f"  {verb} the style specimen — page {body['id']}")
    print(f"  {body['link']}")
    if os.path.exists('site/styles.json'):
        s = json.load(open('site/styles.json')).get('settings', {})
        pal = [c['slug'] for c in s.get('color', {}).get('palette', [])]
        missing = [c for c in ('base', 'contrast', 'primary', 'secondary', 'tertiary', 'accent')
                   if c not in pal]
        if missing:
            print(f"  ! styles.json has no colour named {', '.join(missing)} — "
                  f"those swatches will render with no background.")
    print('  Not recorded under `pages`, so /wp-publish will not push it live.')
    print('  Remove it before handover:  python3 specimen.py '
          f'{cfg_path} --remove')


if __name__ == '__main__':
    main()
