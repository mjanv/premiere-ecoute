// Covers as pixels: each image is read once into a 64×64 grid, then served at any coarser resolution.

const SIZE = 64;

export class Covers {
  constructor() {
    this.entries = new Map();
  }

  load(url) {
    if (!url || this.entries.has(url)) return;

    const entry = { levels: new Map() };
    this.entries.set(url, entry);

    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = SIZE;
      const ctx = canvas.getContext("2d", { willReadFrequently: true });
      ctx.drawImage(image, 0, 0, SIZE, SIZE);
      try {
        entry.levels.set(SIZE, ctx.getImageData(0, 0, SIZE, SIZE).data);
      } catch (_error) {
        // A cover that cannot be read stays a placeholder
      }
    };
    image.src = url;
  }

  // The pixels of a cover at `res` cells per side (RGBA), or null while it is not loaded
  level(url, res) {
    const entry = this.entries.get(url);
    const full = entry?.levels.get(SIZE);
    if (!full) return null;

    res = Math.max(1, Math.min(SIZE, Math.round(res)));
    if (!entry.levels.has(res)) entry.levels.set(res, shrink(full, res));
    return { data: entry.levels.get(res), res };
  }
}

// Averages the 64×64 grid down to res×res cells
function shrink(full, res) {
  const out = new Uint8ClampedArray(res * res * 4);

  for (let cy = 0; cy < res; cy++) {
    for (let cx = 0; cx < res; cx++) {
      const x0 = Math.floor((cx * SIZE) / res);
      const x1 = Math.max(x0 + 1, Math.floor(((cx + 1) * SIZE) / res));
      const y0 = Math.floor((cy * SIZE) / res);
      const y1 = Math.max(y0 + 1, Math.floor(((cy + 1) * SIZE) / res));
      let r = 0;
      let g = 0;
      let b = 0;
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const i = (y * SIZE + x) * 4;
          r += full[i];
          g += full[i + 1];
          b += full[i + 2];
        }
      }
      const n = (x1 - x0) * (y1 - y0);
      const o = (cy * res + cx) * 4;
      out[o] = r / n;
      out[o + 1] = g / n;
      out[o + 2] = b / n;
      out[o + 3] = 255;
    }
  }
  return out;
}
