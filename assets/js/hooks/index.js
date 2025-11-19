import { CopyToClipboard } from "./copy_to_clipboard";
import { FileDownload } from "./file_download";
import { OpenUrl } from "./open_url";
import { PlaylistStorage } from "./playlist_storage";
import { Carousel } from "./carousel";
import { NoteGraph } from "./note_graph";
import { ClickOutside } from "./click_outside";
import { AutoDismissFlash } from "./auto_dismiss_flash";
import { NextTrackTimer } from "./next_track_timer";
import { VisibilityDropdown } from "./visibility_dropdown";
import { SidebarCollapse } from "./sidebar_collapse";



export const Hooks = {
  AutoDismissFlash: AutoDismissFlash,
  CopyToClipboard: CopyToClipboard,
  OpenUrl: OpenUrl,
  FileDownload: FileDownload,
  PlaylistStorage: PlaylistStorage,
  Carousel: Carousel,
  NoteGraph: NoteGraph,
  ClickOutside: ClickOutside,
  NextTrackTimer: NextTrackTimer,
  VisibilityDropdown: VisibilityDropdown,
  SidebarCollapse: SidebarCollapse
};