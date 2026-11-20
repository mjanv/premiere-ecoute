// Fits the viewBox of an SVG around the real ink of its <text>, so the glyphs are
// centred and sized whatever the font's metrics (getBBox() returns the line box,
// not the glyphs). `data-fill` is the share of the box the glyphs take (default 0.7).
let canvas;

function ink(text) {
  canvas ||= document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  const size = parseFloat(text.getAttribute("font-size") || "100");
  const family = text.getAttribute("font-family") || "sans-serif";
  const weight = text.getAttribute("font-weight") || "400";
  ctx.font = `${weight} ${size}px ${family}`;

  const m = ctx.measureText(text.textContent.trim());
  // Digits share one box height, so "8" and "9" sit alike; a placeholder like "--" is centred on its own ink.
  const digits = /\d/.test(text.textContent) ? ctx.measureText("0").actualBoundingBoxAscent : 0;
  return { ascent: Math.max(m.actualBoundingBoxAscent, digits), descent: m.actualBoundingBoxDescent };
}

function fit(svg) {
  const text = svg.querySelector("text");
  if (!text) return;

  const { ascent, descent } = ink(text);
  const stroke = parseFloat(text.getAttribute("stroke-width") || "0") / 2;
  const length = parseFloat(text.getAttribute("textLength"));
  if (!ascent || !length) return;

  const x = parseFloat(text.getAttribute("x") || "0");
  const y = parseFloat(text.getAttribute("y") || "0");
  const left = text.getAttribute("text-anchor") === "middle" ? x - length / 2 : x;

  // Local ink box (baseline at y), mapped through the text's own transform.
  const m = text.transform.baseVal.numberOfItems ? text.transform.baseVal.consolidate().matrix : new DOMMatrix();
  const corners = [
    [left - stroke, y - ascent - stroke],
    [left + length + stroke, y - ascent - stroke],
    [left - stroke, y + descent + stroke],
    [left + length + stroke, y + descent + stroke],
  ].map(([px, py]) => [m.a * px + m.c * py + m.e, m.b * px + m.d * py + m.f]);

  const xs = corners.map((c) => c[0]);
  const ys = corners.map((c) => c[1]);
  const bx = Math.min(...xs);
  const by = Math.min(...ys);
  const bw = Math.max(...xs) - bx;
  const bh = Math.max(...ys) - by;

  const fill = parseFloat(svg.dataset.fill || "0.7");
  const width = bw / fill;
  const height = bh / fill;

  svg.setAttribute("viewBox", `${bx + bw / 2 - width / 2} ${by + bh / 2 - height / 2} ${width} ${height}`);
}

export const FitSvgText = {
  mounted() {
    fit(this.el);
    if (document.fonts) {
      document.fonts.load("700 100px Overlay").then(() => fit(this.el));
      document.fonts.ready.then(() => fit(this.el));
    }
  },
  updated() {
    fit(this.el);
  },
};
