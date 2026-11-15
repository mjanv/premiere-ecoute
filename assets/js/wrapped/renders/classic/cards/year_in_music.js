import { reveal, count } from "./entrances";

// Your year in music: two figures slam in and roll up.
// Returns the animations it starts.
export const enter = (card) => [...reveal(card), ...count(card)];
