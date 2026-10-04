import { chromium } from 'playwright';
import fs from 'fs';

export const BASE = process.env.PW_BASE ?? 'http://localhost:4000';
export const OUT = new URL('./.out/', import.meta.url).pathname;

// System Chrome by default (no download needed); falls back to Playwright's chromium.
export function launch() {
  const chrome = process.env.PW_CHROME ?? '/usr/bin/google-chrome';
  return chromium.launch({ headless: true, ...(fs.existsSync(chrome) && { executablePath: chrome }) });
}

export const statePath = user => `${OUT}state.${user}.json`;
