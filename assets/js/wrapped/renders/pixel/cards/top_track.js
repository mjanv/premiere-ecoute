import { PALETTES } from "../kit";
import { record } from "./record";

// Top track: the album sleeve slides apart and leaves the record of the track spinning.

export const duration = 11;

export const draw = (s, card, t, { labels, covers }) =>
  record(s, card.data.track, t, { pal: PALETTES.plum, covers, label: labels.track_of_year });
