import { CopyToClipboard } from "./copy_to_clipboard";
import { FileDownload } from "./file_download";
import { OpenUrl } from "./open_url";
import { PlaylistStorage } from "./playlist_storage";
 
export const Hooks = {
  CopyToClipboard: CopyToClipboard,
  OpenUrl: OpenUrl,
  FileDownload: FileDownload,
  PlaylistStorage: PlaylistStorage
};