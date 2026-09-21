// Live headless-browser driver for scripts/google_auth_repro.html
// Usage: node scripts/google_auth_repro.mjs [--headful]
// The Google account-picker popup requires a human to select an account;
// the script waits up to 120s for that interaction, then reports the result.
import { chromium } from 'playwright';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import path from 'path';

const headful = process.argv.includes('--headful');
const pagePath = path.resolve('scripts/google_auth_repro.html');
const html = await readFile(pagePath, 'utf8');

const server = createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
}).listen(8123);

console.log('[audit] serving repro page at http://localhost:8123');
const browser = await chromium.launch({ headless: !headful });
const context = await browser.newContext();
const page = await context.newPage();

page.on('console', (msg) => console.log('[browser]', msg.text()));
page.on('requestfailed', (req) => console.log('[net-fail]', req.url(), req.failure()?.errorText));

await page.goto('http://localhost:8123/');
await page.waitForFunction(() => window.__auditReady === true, null, { timeout: 30000 });
console.log('[audit] Firebase initialized OK');

await page.evaluate(() => window.__doSignIn());
console.log('[audit] signInWithPopup triggered — complete the Google account selection in the opened window...');

try {
  await page.waitForFunction(
    () => !!window.__auditResult,
    null,
    { timeout: 120000, polling: 1000 },
  );
  const result = await page.evaluate(() => window.__auditResult);
  console.log('[audit] RESULT =', result);
} catch {
  console.log('[audit] RESULT = TIMEOUT (no account selected within 120s)');
}

await browser.close();
server.close();
process.exit(0);
