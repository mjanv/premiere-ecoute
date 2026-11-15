// Timings of the classic render.

// Time a card stays on screen before the next one, in ms
export const CARD_MS = 8000;
// Press longer than this and the story freezes instead of moving on, in ms
export const HOLD_MS = 220;
// Horizontal travel that turns a press into a swipe, in px
export const SWIPE_PX = 40;

export const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;
