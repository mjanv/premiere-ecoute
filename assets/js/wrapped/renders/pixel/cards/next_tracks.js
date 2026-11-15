import { PALETTES } from "../kit";
import { ranked } from "./ranked";

// Next tracks: the tracks ranked 2 to 5, each one a small spinning record.

export const duration = 10;

export const draw = (s, card, t, { labels, covers }) =>
  ranked(s, card.data.tracks, t, { pal: PALETTES.ember, covers, label: labels.more_tracks, records: true });
