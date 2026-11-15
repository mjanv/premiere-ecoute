import * as start from "./start";
import * as yearInMusic from "./year_in_music";
import * as coverWall from "./cover_wall";
import * as yourMonths from "./your_months";
import * as yourRooms from "./your_rooms";
import * as firstVote from "./first_vote";
import * as topAlbum from "./top_album";
import * as nextAlbums from "./next_albums";
import * as topTrack from "./top_track";
import * as nextTracks from "./next_tracks";
import * as topSingle from "./top_single";
import * as youAndChat from "./you_and_chat";
import * as recap from "./recap";
import { PALETTES, backdrop } from "../kit";

// The scene of each card, by card type. A scene draws one frame from the time elapsed since it began:
// `draw(screen, card, seconds, context)`, and says how long it lasts with `duration`.
const scenes = {
  year_in_music: yearInMusic,
  cover_wall: coverWall,
  your_months: yourMonths,
  your_rooms: yourRooms,
  first_vote: firstVote,
  top_album: topAlbum,
  next_albums: nextAlbums,
  top_track: topTrack,
  next_tracks: nextTracks,
  top_single: topSingle,
  you_and_chat: youAndChat,
  recap,
};

// A card this render does not know: an empty screen, passed quickly
const unknown = { duration: 2, draw: (s) => backdrop(s, PALETTES.plum) };

export { start };
export const scene = (card) => scenes[card.type] || unknown;
