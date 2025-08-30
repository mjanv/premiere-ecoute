import { CopyToClipboard } from "./copy_to_clipboard";
import { FileDownload } from "./file_download";
import { OpenUrl } from "./open_url";
import { PlaylistStorage } from "./playlist_storage";
import { Carousel } from "./carousel";
import { NoteGraph } from "./note_graph";
import { ClickOutside } from "./click_outside";
 
export const Hooks = {
  CopyToClipboard: CopyToClipboard,
  OpenUrl: OpenUrl,
  FileDownload: FileDownload,
  PlaylistStorage: PlaylistStorage,
  Carousel: Carousel,
  NoteGraph: NoteGraph,
  ClickOutside: ClickOutside
};