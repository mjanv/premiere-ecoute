import fs from 'fs';
import { BASE, OUT, launch, statePath } from './browser.mjs';
import { installCursor, glideClick } from './cursor.mjs';

const user = 'lanfeust313';
const dir = `${OUT}nav-${new Date().toISOString().replace(/[:.]/g, '-')}/`;
fs.mkdirSync(dir, { recursive: true });
const b = await launch();
const ctx = await b.newContext({ viewport: { width: 1280, height: 800 }, storageState: statePath(user),
  recordVideo: { dir, size: { width: 1280, height: 800 } } });
await installCursor(ctx);
const p = await ctx.newPage();
await p.goto(BASE + '/home', { waitUntil: 'networkidle' });
await p.waitForSelector('.phx-connected', { timeout: 5000 }).catch(() => {});
await p.waitForTimeout(1000);
for (const name of ['Discographie', 'Sessions', 'Rétrospective', 'Classements', 'Accueil']) {
  await glideClick(p, p.getByRole('navigation').getByRole('link', { name, exact: true }));
  await p.waitForLoadState('networkidle');
  await p.waitForSelector('.phx-connected', { timeout: 5000 }).catch(() => {});
  await p.waitForTimeout(1500);
  console.log(name, '->', new URL(p.url()).pathname);
}
await ctx.close();
await b.close();
console.log(dir);
