import { PALETTES } from "../kit";
import { ranked } from "./ranked";

// Next albums: the albums ranked 2 to 5, their covers put together from scattered tiles.

export const duration = 10;

export const draw = (s, card, t, { labels, covers }) =>
  ranked(s, card.data.albums, t, { pal: PALETTES.sea, covers, label: labels.right_behind });
