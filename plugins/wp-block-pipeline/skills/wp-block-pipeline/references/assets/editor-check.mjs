// Open each page in the WordPress block editor and count block-validation
// warnings — the "Attempt Block Recovery" prompts that the whole approved-block
// rule exists to prevent. A page can push cleanly, render perfectly on the
// front end, and still greet the client with a broken block, so this is the
// only check that actually proves the handoff works.
//
//   node editor-check.mjs               # every page in site/site.json
//   node editor-check.mjs 21 41         # specific page IDs
//
// Needs Playwright. If the project has no node_modules, point it at one:
//   ln -s /path/to/a/project/node_modules node_modules
//
// The admin password is not in site.json — that file holds an application
// password, which wp-login.php will not accept. Playground's sandbox default is
// used unless WP_ADMIN_PASSWORD is set:
//   WP_ADMIN_PASSWORD='...' node editor-check.mjs

import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';

const site = JSON.parse(readFileSync(new URL('./site/site.json', import.meta.url)));
const password = process.env.WP_ADMIN_PASSWORD || 'password';
const ids = process.argv.slice(2).length
  ? process.argv.slice(2)
  : Object.values(site.pages ?? {});

if (!ids.length) {
  console.log('No page IDs given and site.json lists none.');
  process.exit(0);
}

let browser;
try {
  browser = await chromium.launch();
} catch {
  // a cached Playwright build often does not match the browsers this machine
  // downloaded; the installed Chrome still gives a real viewport
  browser = await chromium.launch({ channel: 'chrome' });
}
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });

await page.goto(`${site.url}/wp-login.php`, { waitUntil: 'domcontentloaded' });
await page.fill('#user_login', site.user);
await page.fill('#user_pass', password);
await page.click('#wp-submit');
try {
  await page.waitForURL('**/wp-admin/**', { timeout: 30000 });
} catch {
  console.error('  ! could not log in. Set WP_ADMIN_PASSWORD to the admin password\n'
              + '    (site.json holds an application password, which wp-login.php rejects).');
  await browser.close();
  process.exit(1);
}

let failed = 0;

for (const id of ids) {
  await page.goto(`${site.url}/wp-admin/post.php?post=${id}&action=edit`, {
    waitUntil: 'domcontentloaded',
  });

  const close = page.locator('.components-modal__screen-overlay button[aria-label="Close"]');
  if (await close.count()) await close.first().click().catch(() => {});

  // Visual vs code editor is a persisted user preference, so one stray switch
  // leaves every later session in the code editor — where there is no canvas
  // iframe and no block ever renders. That looks exactly like a page that
  // failed to load, so get out of it before concluding anything.
  const exitCode = page.getByRole('button', { name: /exit code editor/i });
  if (await exitCode.count()) {
    await exitCode.first().click().catch(() => {});
    await page.waitForTimeout(1500);
  }

  // The canvas is an IFRAME. Querying the top document finds zero blocks and
  // zero warnings, which reads as a pass and proves nothing.
  const frame = page.frameLocator('iframe[name="editor-canvas"]');
  try {
    await frame.locator('.wp-block').first().waitFor({ timeout: 30000 });
  } catch {
    console.log(`FAIL page ${id} — no blocks rendered in the editor canvas`);
    failed++;
    continue;
  }
  await page.waitForTimeout(1500);

  const blocks = await frame.locator('.wp-block').count();
  const warnings = await frame.locator('.block-editor-warning').count();

  if (warnings > 0) failed++;
  console.log(`${warnings === 0 ? 'OK  ' : 'FAIL'} page ${id} — ${blocks} blocks, `
            + `${warnings} recovery prompt${warnings === 1 ? '' : 's'}`);
}

await browser.close();
console.log(failed === 0
  ? '\nNo block recovery prompts on any page.'
  : `\n${failed} page(s) need markup fixes. Fix them in allowed-blocks.md, not in the page.`);
process.exit(failed === 0 ? 0 : 1);
