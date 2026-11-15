import { PALETTES } from "../kit";
import { record } from "./record";

// Top single: the same reveal as the top track, with the wide hole and the large label of a 45.

export const duration = 11;

export const draw = (s, card, t, { labels, covers }) =>
  record(s, card.data.single, t, { pal: PALETTES.mint, covers, label: labels.single_of_year, hole: 5, labelSize: 0.55 });
