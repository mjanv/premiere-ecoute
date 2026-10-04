// node tour.mjs <username> </path> [</path> ...]
// Visits each path as <username> (run login.mjs first): screenshot + ARIA snapshot per page,
// one video of the whole tour with a visible cursor, console errors printed. Output: .out/tour-<time>/
import fs from 'fs';
import { BASE, OUT, launch, statePath } from './browser.mjs';
import { installCursor } from './cursor.mjs';

const [user, ...paths] = process.argv.slice(2);
if (!user || !paths.length) { console.error('usage: node tour.mjs <username> </path> ...'); process.exit(1); }
const dir = `${OUT}tour-${new Date().toISOString().replace(/[:.]/g, '-')}/`;
fs.mkdirSync(dir, { recursive: true });

const b = await launch();
const ctx = await b.newContext({ viewport: { width: 1280, height: 800 }, storageState: statePath(user),
  recordVideo: { dir, size: { width: 1280, height: 800 } } });
await installCursor(ctx);
const p = await ctx.newPage();
const errors = [];
p.on('pageerror', e => errors.push(String(e)));

for (const [i, path] of paths.entries()) {
  const name = `${String(i + 1).padStart(2, '0')}-${path.replace(/\W+/g, '_').replace(/^_|_$/g, '') || 'root'}`;
  await p.goto(BASE + path, { waitUntil: 'networkidle' });
  await p.waitForSelector('.phx-connected', { timeout: 5000 }).catch(() => {}); // dead views have no socket
  await p.waitForTimeout(800);
  await p.screenshot({ path: `${dir}${name}.png` });
  fs.writeFileSync(`${dir}${name}.aria.txt`, await p.locator('body').ariaSnapshot());
  console.log(`${path} -> ${new URL(p.url()).pathname} | ${dir}${name}.png`);
}
if (errors.length) console.log('page errors:', errors);
await ctx.close(); // finalizes the video
console.log(`out: ${dir}`);
await b.close();
