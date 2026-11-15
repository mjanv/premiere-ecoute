import { Renderer, Program, Mesh, Triangle } from "ogl";

// Background of the classic render: a liquid gradient tinted with the colours of the current card.

const FALLBACK = ["#6d28d9", "#db2777", "#1e1b4b"];

const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);

// Always three colours: missing ones repeat the previous colour, or fall back on the default palette
export const palette = (colors) => [0, 1, 2].map((i) => colors[i] || colors[i - 1] || FALLBACK[i]);

// Liquid gradient: three colours advected by a slow domain-warped field.
const FRAGMENT = `
  precision highp float;
  uniform float uTime;
  uniform vec2 uRes;
  uniform vec3 uC1;
  uniform vec3 uC2;
  uniform vec3 uC3;
  varying vec2 vUv;

  void main() {
    vec2 p = vUv * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;
    float t = uTime * 0.12;

    for (float i = 1.0; i < 4.0; i++) {
      p.x += 0.45 / i * sin(i * 1.7 * p.y + t * 1.3 + i * 2.1);
      p.y += 0.45 / i * cos(i * 1.4 * p.x + t + i * 0.7);
    }

    float a = 0.5 + 0.5 * sin(p.x * 1.2 + t);
    float b = 0.5 + 0.5 * cos(p.y * 1.4 - t * 0.8);
    vec3 color = mix(uC1, uC2, smoothstep(0.1, 0.9, a));
    color = mix(color, uC3, smoothstep(0.25, 1.0, b) * 0.85);
    gl_FragColor = vec4(color * 0.92, 1.0);
  }
`;

const VERTEX = `
  attribute vec2 uv;
  attribute vec2 position;
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position, 0.0, 1.0);
  }
`;

export class Background {
  constructor(canvas) {
    this.canvas = canvas;
    this.current = palette([]).map(rgb);
    this.target = this.current;

    // Half resolution is plenty for a blurry gradient
    this.renderer = new Renderer({ canvas, dpr: 0.5, alpha: false, antialias: false, powerPreference: "low-power" });
    const gl = this.renderer.gl;

    this.program = new Program(gl, {
      vertex: VERTEX,
      fragment: FRAGMENT,
      uniforms: {
        uTime: { value: 0 },
        uRes: { value: [1, 1] },
        uC1: { value: this.current[0] },
        uC2: { value: this.current[1] },
        uC3: { value: this.current[2] },
      },
    });
    this.mesh = new Mesh(gl, { geometry: new Triangle(gl), program: this.program });

    this.resize = () => {
      const { clientWidth: w, clientHeight: h } = canvas.parentElement;
      this.renderer.setSize(w, h);
      this.program.uniforms.uRes.value = [w, h];
    };
    this.clock = 0;
    this.boost = 0;
    this.frame = (now) => {
      this.raf = requestAnimationFrame(this.frame);
      const delta = Math.min(now - (this.last || now), 100) / 1000;
      this.last = now;
      if (document.hidden) return;

      this.clock += delta * (1 + this.boost * 14);
      this.boost *= 0.93;

      this.current = this.current.map((c, i) => c.map((v, j) => v + (this.target[i][j] - v) * 0.03));
      const u = this.program.uniforms;
      u.uTime.value = this.clock;
      [u.uC1.value, u.uC2.value, u.uC3.value] = this.current;
      this.renderer.render({ scene: this.mesh });
    };

    window.addEventListener("resize", this.resize);
    this.resize();
    this.raf = requestAnimationFrame(this.frame);
    canvas.classList.add("is-live");
  }

  tint(colors) {
    this.target = colors.map(rgb);
  }

  // The gradient surges for a moment, as if the card change stirred it
  kick() {
    this.boost = 1;
  }

  destroy() {
    cancelAnimationFrame(this.raf);
    window.removeEventListener("resize", this.resize);
    this.renderer.gl.getExtension("WEBGL_lose_context")?.loseContext();
  }
}
