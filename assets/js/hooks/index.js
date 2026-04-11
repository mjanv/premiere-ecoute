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
import { AriadneThread } from "./ariadne_thread";
import { ScrollCarousel } from "./scroll_carousel";
import VegaLite from "./vegalite";
import { MotionDemo } from "./motion_demo";
import { LikeHeart } from "./like_heart";
import { BarBounce } from "./bar_bounce";
import { BackLink } from "./back_link";
import { ScrollToActive } from "./scroll_to_active";
import { ClampText } from "./clamp_text";
import { Microphone } from "./microphone";
import { Drawer } from "./drawer";
import { WikipediaDrawer } from "./wikipedia_drawer";
import { PlaySound } from "./play_sound";
import { ShareButton } from "./share_button";

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
  SidebarCollapse: SidebarCollapse,
  AriadneThread: AriadneThread,
  ScrollCarousel: ScrollCarousel,
  VegaLite: VegaLite,
  MotionDemo: MotionDemo,
  LikeHeart: LikeHeart,
  BarBounce: BarBounce,
  BackLink: BackLink,
  ScrollToActive: ScrollToActive,
  ClampText: ClampText,
  Microphone: Microphone,
  Drawer: Drawer,
  WikipediaDrawer: WikipediaDrawer,
  PlaySound: PlaySound,
  ShareButton: ShareButton
};