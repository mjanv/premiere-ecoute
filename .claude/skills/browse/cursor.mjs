// Visible cursor for Playwright videos: overlay that follows the mouse + click ripple.
// Headless Chrome records page pixels only, so the real cursor never shows up.
export async function installCursor(ctx) {
  await ctx.addInitScript(() => {
    const mount = () => {
      if (document.getElementById('pw-cursor')) return;
      const c = document.createElement('div');
      c.id = 'pw-cursor';
      c.style.cssText = 'position:fixed;top:0;left:0;width:22px;height:22px;z-index:2147483647;pointer-events:none;transform:translate(-100px,-100px);';
      c.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24"><path d="M3 2l7 19 3-8 8-3z" fill="#fff" stroke="#000" stroke-width="1.5" stroke-linejoin="round"/></svg>';
      const s = document.createElement('style');
      s.textContent = '@keyframes pw-ripple{from{transform:translate(-50%,-50%) scale(.3);opacity:.9}to{transform:translate(-50%,-50%) scale(2.2);opacity:0}}';
      document.documentElement.append(s, c);
      addEventListener('mousemove', e => { c.style.transform = `translate(${e.clientX}px,${e.clientY}px)`; }, true);
      addEventListener('mousedown', e => {
        const r = document.createElement('div');
        r.style.cssText = `position:fixed;left:${e.clientX}px;top:${e.clientY}px;width:36px;height:36px;border-radius:50%;background:rgba(250,204,21,.55);border:2px solid #facc15;z-index:2147483646;pointer-events:none;animation:pw-ripple .5s ease-out forwards`;
        document.documentElement.append(r);
        setTimeout(() => r.remove(), 600);
      }, true);
    };
    document.readyState === 'loading' ? addEventListener('DOMContentLoaded', mount) : mount();
  });
}

// Glide the mouse to the center of a locator, pause, then click.
export async function glideClick(page, locator, { steps = 30, pause = 350 } = {}) {
  await locator.scrollIntoViewIfNeeded();
  const box = await locator.boundingBox();
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await page.mouse.move(x, y, { steps });
  await page.waitForTimeout(pause);
  await page.mouse.click(x, y);
}
