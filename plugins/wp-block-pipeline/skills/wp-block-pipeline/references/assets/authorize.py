#!/usr/bin/env python3
"""
Connect a project to a WordPress site without anyone typing a password.

Uses WordPress's own Application Password authorization flow. We start a
listener on 127.0.0.1, open the site's authorize screen in the browser, and
WordPress redirects back with the credential once the person clicks Approve.

The password goes browser -> localhost -> config file. It is never typed, never
pasted, and never passes through a chat transcript or shell history.

    python3 authorize.py https://example.com
    python3 authorize.py https://example.com --out site/site.live.json

Requires: the site on HTTPS, and the person logged into wp-admin in their
default browser. WordPress refuses the flow over plain http for anything but
localhost, and hides Application Passwords entirely on a non-SSL site.
"""
import http.server, threading, urllib.parse, webbrowser, json, sys, os, socket, time

APP_NAME = "Highland Sites pipeline"
PAGE = """<!doctype html><meta charset="utf-8"><title>%s</title>
<style>body{font:16px/1.6 -apple-system,sans-serif;max-width:34rem;margin:18vh auto;
padding:0 1.5rem;color:#141C22}h1{font-size:1.4rem;letter-spacing:-.02em}
.ok{color:#1F3D5A}.no{color:#B4552D}</style><h1 class="%s">%s</h1><p>%s</p>"""

def free_port():
    s = socket.socket(); s.bind(('127.0.0.1', 0)); p = s.getsockname()[1]; s.close(); return p

def authorize(site_url, out_path, app_name=APP_NAME, timeout=300):
    site_url = site_url.rstrip('/')
    port = free_port()
    captured = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a): pass          # keep the console clean
        def do_GET(self):
            parts = urllib.parse.urlparse(self.path)
            q = {k: v[0] for k, v in urllib.parse.parse_qs(parts.query).items()}
            if parts.path == '/reject':
                body = PAGE % (app_name, 'no', 'Rejected', 'Nothing was saved. You can close this tab.')
                captured['rejected'] = True
            elif 'password' in q and 'user_login' in q:
                captured.update(q)
                body = PAGE % (app_name, 'ok', 'Connected',
                               'The credential was saved locally. You can close this tab.')
            else:
                body = PAGE % (app_name, 'no', 'Something went wrong',
                               'WordPress did not send a credential. Check the site is on HTTPS.')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(body.encode())
            threading.Thread(target=self.server.shutdown, daemon=True).start()

    server = http.server.HTTPServer(('127.0.0.1', port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    args = urllib.parse.urlencode({
        'app_name': app_name,
        'success_url': f'http://127.0.0.1:{port}/callback',
        'reject_url':  f'http://127.0.0.1:{port}/reject',
    })
    url = f'{site_url}/wp-admin/authorize-application.php?{args}'
    print(f'  Opening the authorization screen for {site_url}')
    print(f'  If the browser does not open, paste this:\n\n    {url}\n')
    webbrowser.open(url)

    waited = 0
    while not captured and waited < timeout:
        time.sleep(0.4); waited += 0.4
    server.server_close()

    if captured.get('rejected'):
        print('  Rejected in the browser. Nothing saved.'); return 1
    if 'password' not in captured:
        print(f'  Timed out after {timeout}s with no response.'); return 1

    cfg = {}
    if os.path.exists(out_path):
        cfg = json.load(open(out_path))          # keep the page and media ID maps
    cfg.update({
        'url': captured.get('site_url', site_url).rstrip('/'),
        'user': captured['user_login'],
        'app_password': captured['password'],
    })
    cfg.setdefault('pages', {}); cfg.setdefault('media', {})
    os.makedirs(os.path.dirname(out_path) or '.', exist_ok=True)
    json.dump(cfg, open(out_path, 'w'), indent=2)
    os.chmod(out_path, 0o600)
    print(f'  Connected as {cfg["user"]}. Wrote {out_path} (mode 600).')
    return 0

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(2)
    out = 'site/site.live.json'
    if '--out' in sys.argv: out = sys.argv[sys.argv.index('--out') + 1]
    sys.exit(authorize(sys.argv[1], out))
