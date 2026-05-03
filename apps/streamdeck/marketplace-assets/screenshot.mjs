import puppeteer from 'puppeteer';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const files = [
  { html: 'thumbnail.html',       png: 'thumbnail.png',  w: 1920, h: 960  },
  { html: 'gallery-1-setup.html', png: 'gallery-1.png',  w: 1920, h: 960  },
  { html: 'gallery-2-keys.html',  png: 'gallery-2.png',  w: 1920, h: 960  },
  { html: 'gallery-3-live.html',  png: 'gallery-3.png',  w: 1920, h: 960  },
  { html: '_icon.html',           png: 'icon.png',        w: 288,  h: 288  },
];

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});

for (const { html, png, w, h } of files) {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 });
  await page.goto(`file://${path.join(__dirname, html)}`);
  await page.screenshot({ path: path.join(__dirname, png), clip: { x: 0, y: 0, width: w, height: h } });
  await page.close();
  console.log(`✓ ${png}`);
}

await browser.close();
