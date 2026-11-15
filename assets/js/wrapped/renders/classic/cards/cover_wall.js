import { reveal, wall, drift } from "./entrances";

// Cover wall: the covers land one by one, then the wall drifts up if it is taller than the stage.
// Returns the animations it starts.
export const enter = (card) => [...reveal(card), ...wall(card), ...drift(card)];
