import { reveal } from "./entrances";

// First vote: the cover is thrown onto the card, then its name and its date rise.
// Returns the animations it starts.
export const enter = (card) => reveal(card);
