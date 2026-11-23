// Animated film grain for the overlay's great mode, like the per-pixel noise of
// priv/demos/liquid-type.html. A few noise tiles are rendered once and redrawn as a
// pattern at a random offset every frame, so the grain moves at almost no cost.
// The canvas is blended with `mix-blend-mode: screen`: it lifts black a little and
// barely touches bright colours.
import { fitCanvas } from "./overlay_canvas";

// Tuning knobs
const STRENGTH = 0.09; // brightest grain level (0..1)
const TILE = 192; // noise tile side, in canvas pixels
const TILES = 4; // number of pre-rendered tiles
const FPS = 24; // grain refresh rate

function tile(size) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  const image = ctx.createImageData(size, size);
  for (let i = 0; i < image.data.length; i += 4) {
    const v = Math.round(255 * STRENGTH * Math.random());
    image.data[i] = image.data[i + 1] = image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  ctx.putImageData(image, 0, 0);
  return canvas;
}

export const FilmGrain = {
  mounted() {
    const canvas = this.el;
    const ctx = canvas.getContext("2d");
    const patterns = Array.from({ length: TILES }, () => ctx.createPattern(tile(TILE), "repeat"));
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
    let last = 0;

    const draw = () => {
      fitCanvas(canvas);
      const pattern = patterns[(Math.random() * TILES) | 0];
      pattern.setTransform(new DOMMatrix([1, 0, 0, 1, Math.random() * TILE, Math.random() * TILE]));
      ctx.fillStyle = pattern;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    };

    const frame = (now) => {
      if (this.gone) return;
      if (now - last >= 1000 / FPS) {
        last = now;
        draw();
      }
      this.raf = requestAnimationFrame(frame);
    };
    draw();
    if (!reduced) this.raf = requestAnimationFrame(frame);
  },

  destroyed() {
    this.gone = true;
    if (this.raf) cancelAnimationFrame(this.raf);
  },
};
