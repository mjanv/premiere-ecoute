// "Great score" paint for the session overlay, after priv/demos/liquid-type.html:
// the demo's flowing four-colour gradient (warped sine flow through the palette),
// without the text mask and without the blur. In great mode the server paints every
// overlay colour white; this canvas covers the widget with `mix-blend-mode: multiply`,
// so white becomes the gradient and black stays black (borders, label, counter, score
// digits and progress bar all flow together).
// Without WebGL 2 it draws a static horizontal gradient of the same palette.
import { fitCanvas, onResize, rgb } from "./overlay_canvas";

// Tuning knobs
const PALETTE = ["#4a2bff", "#ff3df2", "#ffb8ff", "#ff2d55"]; // demo "Neon"
const SCALE = 1.2; // flow scale, in widget heights (higher = smaller swirls)
const SPEED = 1; // multiplies the flow speed
const BANDS = 0.6; // colour bands per flow unit (demo: 0.3); higher packs more bands into each stroke
const DETAIL = 0.35; // strength of a fine ripple over the flow, so even thin strokes hold several tints
const RIPPLE = 3.5; // scale of that ripple, relative to the flow

const VERT = `#version 300 es
in vec2 position;
void main() { gl_Position = vec4(position, 0.0, 1.0); }`;

const FRAG = `#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform float uTime;
uniform float uScale;
uniform float uBands;
uniform float uDetail;
uniform float uRipple;
uniform vec3 uColors[4];

vec3 palette(float p) {
  float f = fract(p) * 4.0;
  int i = int(floor(f));
  float k = smoothstep(0.0, 1.0, fract(f));
  return mix(uColors[i], uColors[(i + 1) % 4], k);
}

void main() {
  float t = uTime;
  vec2 p = gl_FragCoord.xy / uRes.y * uScale;
  for (int i = 1; i <= 4; i++) {
    float n = float(i);
    p += (0.36 / n) * sin(p.yx * n * 1.15 + t * (0.32 + 0.07 * n) + vec2(1.7, 4.1) * n);
  }
  // A second, finer warp of the same kind ripples the bands.
  vec2 q = p * uRipple;
  for (int i = 1; i <= 2; i++) {
    float n = float(i);
    q += (0.5 / n) * sin(q.yx * n * 1.3 - t * (0.5 + 0.1 * n) + vec2(2.3, 0.7) * n);
  }
  float ripple = sin(q.x + q.y) * 0.5 + sin(q.x * 1.7 - q.y * 0.6) * 0.25;
  vec3 col = palette(uBands * (p.x + p.y) + uDetail * ripple + t * 0.045);
  float g = fract(sin(dot(gl_FragCoord.xy + t, vec2(12.9898, 78.233))) * 43758.5453);
  outColor = vec4(col + (g - 0.5) * 0.025, 1.0);
}`;

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
  return shader;
}

function program(gl) {
  const prog = gl.createProgram();
  gl.attachShader(prog, compile(gl, gl.VERTEX_SHADER, VERT));
  gl.attachShader(prog, compile(gl, gl.FRAGMENT_SHADER, FRAG));
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
  gl.useProgram(prog);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(prog, "position");
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
  const u = {};
  for (const name of ["uRes", "uTime", "uScale", "uBands", "uDetail", "uRipple", "uColors"]) u[name] = gl.getUniformLocation(prog, name);
  gl.uniform3fv(u.uColors, PALETTE.flatMap((c) => rgb(c).map((v) => v / 255)));
  return u;
}

// Static fallback: the palette as a horizontal gradient.
function flat(canvas) {
  const ctx = canvas.getContext("2d");
  const g = ctx.createLinearGradient(0, 0, canvas.width, 0);
  PALETTE.forEach((c, i) => g.addColorStop(i / (PALETTE.length - 1), c));
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

export const LiquidField = {
  mounted() {
    const canvas = this.el;
    const gl = canvas.getContext("webgl2", { antialias: false, alpha: false });
    let u = null;
    try {
      if (gl) u = program(gl);
    } catch (error) {
      console.error(error);
    }
    if (!u) {
      this.observer = onResize(canvas, () => flat(canvas));
      return;
    }

    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const frame = (now) => {
      if (this.gone) return;
      if (!gl.isContextLost()) {
        if (fitCanvas(canvas).changed) gl.viewport(0, 0, canvas.width, canvas.height);
        gl.uniform2f(u.uRes, canvas.width, canvas.height);
        gl.uniform1f(u.uTime, reduced ? 3 : (now / 1000) * SPEED);
        gl.uniform1f(u.uScale, SCALE);
        gl.uniform1f(u.uBands, BANDS);
        gl.uniform1f(u.uDetail, DETAIL);
        gl.uniform1f(u.uRipple, RIPPLE);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      }
      this.raf = reduced ? null : requestAnimationFrame(frame);
    };
    this.raf = requestAnimationFrame(frame);
  },

  destroyed() {
    this.gone = true;
    if (this.raf) cancelAnimationFrame(this.raf);
    this.observer?.disconnect();
  },
};
