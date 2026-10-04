// node login.mjs <username>   -> saves .out/state.<username>.json (session cookies, gitignored)
import { execFileSync } from 'child_process';
import fs from 'fs';
import { BASE, OUT, launch, statePath } from './browser.mjs';

const user = process.argv[2] ?? process.env.PW_USER;
if (!user) { console.error('usage: node login.mjs <username>'); process.exit(1); }
if (!/^https?:\/\/(localhost|127\.0\.0\.1)(:|\/|$)/.test(BASE)) { console.error(`refusing non-local PW_BASE ${BASE}`); process.exit(1); }

// `elixir` must run from the repo so asdf picks the project's version.
const repo = new URL('../../../', import.meta.url).pathname;
let token;
try {
  token = execFileSync('elixir', ['--sname', `pwlogin${process.pid}`, '--hidden', new URL('./login-token.exs', import.meta.url).pathname],
    { cwd: repo, env: { ...process.env, PW_USER: user }, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
} catch (e) {
  console.error(e.stderr?.trim() || e.message);
  process.exit(1);
}

fs.mkdirSync(OUT, { recursive: true });
const b = await launch();
const ctx = await b.newContext({ viewport: { width: 1280, height: 800 } });
const p = await ctx.newPage();
await p.goto(`${BASE}/users/log-in/${token}`, { waitUntil: 'networkidle' });
await p.waitForSelector('.phx-connected');
await p.getByRole('button', { name: 'Log in', exact: true }).click();
await p.waitForURL(u => !u.pathname.startsWith('/users/log-in'), { timeout: 15000 });
await ctx.storageState({ path: statePath(user) });
console.log(`logged in as ${user} -> ${p.url()}\nstate: ${statePath(user)}`);
await b.close();
