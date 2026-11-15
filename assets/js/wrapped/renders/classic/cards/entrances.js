import { animate, stagger } from "motion";
import { CARD_MS } from "../config";

// Building blocks of the card entrances. Each function starts animations and returns them,
// so that the player can pause, resume or finish them.

const soft = { type: "spring", stiffness: 140, damping: 18 };
const hard = { type: "spring", stiffness: 320, damping: 17 };

// How an element marked `data-in="<kind>"` comes in
const kinds = {
  up: () => [{ opacity: [0, 1], y: [40, 0] }, soft],
  left: () => [{ opacity: [0, 1], x: [-60, 0] }, soft],
  // Lands from far too big, with a bounce
  slam: () => [{ opacity: [0, 1], scale: [3.2, 1] }, hard],
  // A cover thrown onto the card: oversized and tilted, settling slightly askew
  hero: () => [{ opacity: [0, 1], scale: [1.7, 1], rotate: [-18, -3] }, { type: "spring", stiffness: 180, damping: 15 }],
  // A column growing from its base
  bar: () => [{ opacity: [0, 1], scaleY: [0, 1] }, soft],
  fan: (item) => [{ opacity: [0, 1], y: [120, 0], scale: [0.5, 1], rotate: [0, Number(item.dataset.rotate || 0)] }, hard],
};

// The elements marked `data-in` come in one after the other. Covers (`data-in="cover"`) are left to `wall`.
export function reveal(card) {
  const items = [...card.querySelectorAll("[data-in]")].filter((item) => item.dataset.in !== "cover");

  return items.map((item, i) => {
    const [keyframes, transition] = (kinds[item.dataset.in] || kinds.up)(item);
    return animate(item, keyframes, { ...transition, delay: 0.3 + i * 0.16 });
  });
}

// The covers of a wall land in about 1.8 s, however many there are
export function wall(card) {
  const covers = [...card.querySelectorAll('[data-in="cover"]')];
  if (!covers.length) return [];

  const each = Math.min(0.08, 1.8 / covers.length);
  return [
    animate(
      covers,
      { opacity: [0, 1], scale: [0.2, 1], rotate: [-25, 0] },
      { type: "spring", stiffness: 260, damping: 19, delay: stagger(each, { startDelay: 0.3 }) }
    ),
  ];
}

// An element marked `data-drift` taller than the stage drifts up so that all of it passes by
export function drift(card) {
  return [...card.querySelectorAll("[data-drift]")].flatMap((element) => {
    const overflow = element.offsetHeight - card.offsetHeight * 0.92;
    element.style.transform = "";
    if (overflow <= 0) return [];

    return [animate(element, { y: [0, -overflow] }, { duration: CARD_MS / 1000 - 2.4, delay: 2, ease: [0.45, 0, 0.55, 1] })];
  });
}

// The numbers marked `data-count` roll up from zero
export function count(card) {
  return [...card.querySelectorAll("[data-count]")].flatMap((counter, i) => {
    const total = parseInt(counter.textContent, 10);
    if (Number.isNaN(total)) return [];

    return [
      animate(0, total, {
        duration: 1.4,
        delay: 0.45 + i * 0.3,
        ease: [0.16, 1, 0.3, 1],
        onUpdate: (value) => (counter.textContent = Math.round(value)),
        onComplete: () => (counter.textContent = total),
      }),
    ];
  });
}
