import { clean, glyph } from "./font";
import { Layer, paper } from "./poster";

// The screen of the pixel render: three layers composed on one canvas for every frame.
//
//   back   poster artwork at full resolution: flat colours, gradient panels, glows
//   grid   the pixels: a grid 126 wide, as tall as the stage allows, scaled up without smoothing
//   front  type and thin lines at full resolution, then a sheet of worn paper over everything
//
// The three share one coordinate system: a unit is one pixel of the grid.

export const COLS = 126;

const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
// Device pixels per unit: whole, so that every pixel of the grid has the same size
const MIN_UNIT = 2;
const MAX_UNIT = 8;

// Ordered-dither threshold of a pixel, between 0 and 1
export const bayer = (x, y) => (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16;

export const hex = (color) => {
  const n = parseInt(color.slice(1), 16);
  return [n >> 16, (n >> 8) & 255, n & 255];
};

export const mix = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];

const offscreen = () => {
  const canvas = document.createElement("canvas");
  return [canvas, canvas.getContext("2d")];
};

export class Screen {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    [this.gridCanvas, this.gridCtx] = offscreen();
    [this.frontCanvas, this.frontCtx] = offscreen();
    [this.oldCanvas, this.oldCtx] = offscreen();
    [this.fxCanvas, this.fxCtx] = offscreen();
    [this.maskCanvas, this.maskCtx] = offscreen();

    this.back = new Layer(this.ctx);
    this.front = new Layer(this.frontCtx);
    this.w = COLS;
    this.h = 0;
    this.unit = 0;
    this.resize();
  }

  // Keeps pixels square: the grid grows in height with the stage
  resize() {
    const box = this.canvas.parentElement;
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const unit = Math.min(MAX_UNIT, Math.max(MIN_UNIT, Math.round((box.clientWidth * ratio) / COLS)));
    const h = Math.max(180, Math.round((COLS * box.clientHeight) / Math.max(1, box.clientWidth)));
    if (h === this.h && unit === this.unit) return;

    this.h = h;
    this.unit = unit;
    for (const canvas of [this.canvas, this.frontCanvas, this.oldCanvas, this.fxCanvas]) {
      canvas.width = COLS * unit;
      canvas.height = h * unit;
    }
    for (const canvas of [this.gridCanvas, this.maskCanvas]) {
      canvas.width = COLS;
      canvas.height = h;
    }
    this.image = this.gridCtx.createImageData(COLS, h);
    this.data = this.image.data;
    this.mask = this.maskCtx.createImageData(COLS, h);
    this.papers = {};
    this.old = false;
    this.back.h = this.front.h = h;
  }

  // Starts a frame: every layer is emptied
  begin() {
    this.resize();
    this.data.fill(0);
    for (const ctx of [this.ctx, this.frontCtx]) {
      ctx.setTransform(this.unit, 0, 0, this.unit, 0, 0);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      ctx.clearRect(0, 0, this.w, this.h);
    }
    // Scenes say what their paper is with `backdrop`: ink on a light one, light on a dark one
    this.light = false;
    this.ink = [255, 255, 255];
    this.foot = null;
  }

  // Ends a frame: the pixels go over the artwork, then the type, then the paper
  compose() {
    const ctx = this.ctx;
    const tone = this.light ? "light" : "dark";
    this.papers[tone] ||= paper(this.w, this.h, this.unit, this.light);

    this.gridCtx.putImageData(this.image, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(this.gridCanvas, 0, 0, this.w, this.h);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(this.frontCanvas, 0, 0, this.w, this.h);
    ctx.drawImage(this.papers[tone], 0, 0, this.w, this.h);
  }

  px(x, y, color) {
    x |= 0;
    y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    this.data[i] = color[0];
    this.data[i + 1] = color[1];
    this.data[i + 2] = color[2];
    this.data[i + 3] = 255;
  }

  rect(x, y, w, h, color) {
    const x1 = Math.min(this.w, Math.round(x + w));
    const y1 = Math.min(this.h, Math.round(y + h));
    for (let j = Math.max(0, Math.round(y)); j < y1; j++) for (let i = Math.max(0, Math.round(x)); i < x1; i++) this.px(i, j, color);
  }

  // Two colours mixed by ordered dithering. `level` is the share of `b`: a number, or a function of the pixel.
  // Without `a`, the pixels it would take stay empty and show the artwork behind.
  dither(x, y, w, h, a, b, level) {
    const x1 = Math.min(this.w, Math.round(x + w));
    const y1 = Math.min(this.h, Math.round(y + h));
    for (let j = Math.max(0, Math.round(y)); j < y1; j++) {
      for (let i = Math.max(0, Math.round(x)); i < x1; i++) {
        const k = typeof level === "function" ? level(i, j) : level;
        if (bayer(i, j) < k) this.px(i, j, b);
        else if (a) this.px(i, j, a);
      }
    }
  }

  measure(text, scale = 1) {
    const length = clean(text).length;
    return length ? (length * 6 - 1) * scale : 0;
  }

  // Draws a line of text in the bitmap font. `align` places it around x: "left", "center" or "right". Returns its width.
  text(text, x, y, { scale = 1, color = [255, 255, 255], align = "left" } = {}) {
    const line = clean(text);
    const width = this.measure(line, scale);
    let left = Math.round(align === "center" ? x - width / 2 : align === "right" ? x - width : x);

    for (const char of line) {
      const rows = glyph(char);
      if (rows) {
        for (let j = 0; j < 7; j++) {
          for (let i = 0; i < 5; i++) {
            if (rows[j][i] === "#") this.rect(left + i * scale, y + j * scale, scale, scale, color);
          }
        }
      }
      left += 6 * scale;
    }
    return width;
  }

  // Keeps the frame on screen, to dissolve it into the next scene
  snapshot() {
    this.oldCtx.clearRect(0, 0, this.oldCanvas.width, this.oldCanvas.height);
    this.oldCtx.drawImage(this.canvas, 0, 0);
    this.old = true;
  }

  // Shows the kept frame through the blocks the ordered dither has not released yet: 0 is all old, 1 all new
  dissolve(progress) {
    if (!this.old || progress >= 1) return;

    const mask = this.mask.data;
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) mask[(y * this.w + x) * 4 + 3] = bayer(x >> 1, y >> 1) < progress ? 0 : 255;
    }
    this.maskCtx.putImageData(this.mask, 0, 0);

    const fx = this.fxCtx;
    fx.globalCompositeOperation = "source-over";
    fx.clearRect(0, 0, this.fxCanvas.width, this.fxCanvas.height);
    fx.drawImage(this.oldCanvas, 0, 0);
    fx.globalCompositeOperation = "destination-in";
    fx.imageSmoothingEnabled = false;
    fx.drawImage(this.maskCanvas, 0, 0, this.fxCanvas.width, this.fxCanvas.height);

    this.ctx.drawImage(this.fxCanvas, 0, 0, this.w, this.h);
  }
}
