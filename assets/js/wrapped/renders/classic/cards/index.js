import { enter as yearInMusic } from "./year_in_music";
import { enter as coverWall } from "./cover_wall";
import { enter as yourMonths } from "./your_months";
import { enter as yourRooms } from "./your_rooms";
import { enter as firstVote } from "./first_vote";
import { enter as topAlbum } from "./top_album";
import { enter as nextAlbums } from "./next_albums";
import { enter as topTrack } from "./top_track";
import { enter as nextTracks } from "./next_tracks";
import { enter as topSingle } from "./top_single";
import { enter as youAndChat } from "./you_and_chat";
import { enter as recap } from "./recap";
import { reveal } from "./entrances";

// Entrance of each card, by card type (the `data-type` of its section).
const entrances = {
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
  recap: recap,
};

// Starts the entrance of a card and returns its animations. A card of an unknown type gets the plain reveal.
export const enter = (card) => (entrances[card.dataset.type] || reveal)(card);
