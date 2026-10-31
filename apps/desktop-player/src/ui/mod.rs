//! The window: cover-tinted palette, poster title, a minute ruler, transport, and the link strip.

pub mod assets;
pub mod palette;
pub mod ruler;

use crate::artwork::{self, Artwork};
use crate::light::Light;
use crate::player::{self, Command, Request, Snapshot, format_time, lock};
use crate::remote;
use crate::remote_status::{Link, RemoteStatus, SessionInfo, SessionState};
use crate::status::{self, Check, CheckState, SessionView, Verdict};
use crate::waveform::Scope;
use gpui::prelude::FluentBuilder;
use gpui_kit::component::input::{Input, InputEvent, InputState};
use gpui_kit::component::slider::{Slider, SliderEvent, SliderState};
use gpui_kit::component::{Theme, TitleBar};
use gpui_kit::*;
use palette::{Palette, Rgb};
use ruler::{TickKind, ticks};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

pub const POLL: Duration = Duration::from_millis(750);
/// Repaint interval while the waveform moves.
const SMOOTH: Duration = Duration::from_millis(33);
/// Points of the line across the box.
const TRACE_POINTS: usize = 200;
/// After the user moves the slider, ignore polled volume for this long so the thumb doesn't jump back.
const VOLUME_HOLD: Duration = Duration::from_millis(1500);

const DISPLAY: &str = "Anton";
const MONO: &str = "DM Mono";

fn col(c: Rgb) -> Hsla {
    rgb(c.hex()).into()
}

pub struct NowPlaying {
    shared: Arc<Mutex<Snapshot>>,
    remote: Arc<Mutex<RemoteStatus>>,
    scope: Arc<Mutex<Scope>>,
    commands: Sender<Request>,
    remote_handle: Option<remote::Handle>,
    server_input: Entity<InputState>,
    editing_server: bool,
    server_error: Option<String>,
    volume: Entity<SliderState>,
    volume_touched: Option<Instant>,
    cover: Option<(u64, Arc<Image>)>,
    palette: Option<Palette>,
    #[cfg(windows)]
    badge: Option<crate::taskbar::Badge>,
    #[cfg(windows)]
    tray: Option<crate::tray::Tray>,
    _volume_sub: Subscription,
}

impl NowPlaying {
    pub fn editing_server(mut self, editing: bool) -> Self {
        self.editing_server = editing;
        self
    }

    pub fn new(
        window: &mut Window,
        cx: &mut Context<Self>,
        shared: Arc<Mutex<Snapshot>>,
        remote: Arc<Mutex<RemoteStatus>>,
        scope: Arc<Mutex<Scope>>,
        commands: Sender<Request>,
        remote_handle: Option<remote::Handle>,
    ) -> Self {
        // Repaint calmly, and smoothly (about 30 times a second) while sound is scrolling by.
        let (watched_snapshot, watched_scope) = (shared.clone(), scope.clone());
        let (light_snapshot, light_remote) = (shared.clone(), remote.clone());
        cx.spawn(async move |this, cx| {
            loop {
                let busy = lock(&watched_snapshot).playback == player::Playback::Playing
                    && lock(&watched_scope).is_live(Instant::now());
                cx.background_executor()
                    .timer(if busy { SMOOTH } else { POLL / 3 })
                    .await;
                // The light is set here, not in `render`: a minimized window may not repaint.
                let light = Light::of(&lock(&light_snapshot), &lock(&light_remote), Instant::now());
                let updated = this.update(cx, |this, cx| {
                    #[cfg(windows)]
                    {
                        if let Some(badge) = this.badge.as_mut() {
                            badge.show(light);
                        }
                        if let Some(tray) = this.tray.as_mut() {
                            tray.set_light(light);
                            if tray.poll().is_some() {
                                cx.quit();
                            }
                        }
                    }
                    #[cfg(not(windows))]
                    let _ = (this, light);
                    cx.notify()
                });
                if updated.is_err() {
                    break;
                }
            }
        })
        .detach();

        let volume = cx.new(|_| SliderState::new().min(0.0).max(1.0).step(0.01));
        let _volume_sub = cx.subscribe(&volume, |this, _, event: &SliderEvent, _| {
            let SliderEvent::Change(value) = event else {
                return;
            };
            this.volume_touched = Some(Instant::now());
            let _ = this
                .commands
                .send(Request::local(Command::SetVolume(value.end())));
        });

        let server_input = cx.new(|cx| {
            InputState::new(window, cx)
                .placeholder("Server address, for example https://…")
                .default_value(
                    remote::config::load()
                        .unwrap_or_else(|| remote::config::DEFAULT_SERVER.to_string()),
                )
        });
        cx.subscribe(&server_input, |this, _, event: &InputEvent, cx| {
            if matches!(event, InputEvent::PressEnter { .. }) {
                this.connect_server(cx);
            }
        })
        .detach();

        Self {
            shared,
            remote,
            scope,
            commands,
            remote_handle,
            server_input,
            editing_server: false,
            server_error: None,
            volume,
            volume_touched: None,
            cover: None,
            palette: None,
            #[cfg(windows)]
            badge: crate::taskbar::Badge::for_window(window),
            #[cfg(windows)]
            tray: crate::taskbar::hwnd_of(window).and_then(crate::tray::Tray::start),
            _volume_sub,
        }
    }

    /// Stops the link to the current server and offers the address field again, so another server
    /// can be chosen. The credential of the old server is kept.
    fn change_server(&mut self, cx: &mut Context<Self>) {
        if let Some(handle) = self.remote_handle.take() {
            handle.stop();
        }
        if let Err(message) = remote::config::forget() {
            crate::log::warn(message);
        }
        *lock(&self.remote) = RemoteStatus::default();
        self.server_error = None;
        self.editing_server = true;
        cx.notify();
    }

    /// Validates the address in the field, saves it and starts the backend link.
    fn connect_server(&mut self, cx: &mut Context<Self>) {
        let text = self.server_input.read(cx).value();
        let started = remote::Settings::parse(text.trim()).and_then(|settings| {
            remote::config::save(&settings.base_url)?;
            Ok(settings)
        });
        match started {
            Ok(settings) => {
                self.server_error = None;
                self.editing_server = false;
                if self.remote_handle.is_none() {
                    self.remote_handle = Some(remote::start(
                        settings,
                        self.shared.clone(),
                        self.commands.clone(),
                        self.remote.clone(),
                    ));
                }
            }
            Err(message) => self.server_error = Some(message),
        }
        cx.notify();
    }

    /// Pushes the palette into the component theme so sliders and inputs match the cover.
    fn apply_theme(&mut self, p: Palette, cx: &mut Context<Self>) {
        if self.palette == Some(p) {
            return;
        }
        self.palette = Some(p);
        let t = Theme::global_mut(cx);
        t.colors.background = col(p.bg);
        t.colors.foreground = col(p.ink);
        t.colors.muted_foreground = col(p.muted);
        t.colors.primary = col(p.accent);
        t.colors.primary_foreground = col(p.on_accent);
        t.colors.secondary = col(p.surface);
        t.colors.input = col(p.muted).opacity(0.35);
        t.colors.border = col(p.muted).opacity(0.35);
        t.colors.ring = col(p.accent);
        t.colors.caret = col(p.accent);
        t.colors.selection = col(p.accent).opacity(0.3);
        t.colors.slider_bar = col(p.accent);
        t.colors.slider_thumb = col(p.ink);
        t.colors.title_bar = col(p.bg);
        t.colors.title_bar_border = col(p.bg);
    }

    fn cover_image(&mut self, art: Option<&Artwork>) -> Option<Arc<Image>> {
        let art = art?;
        if self.cover.as_ref().map(|(id, _)| *id) != Some(art.id) {
            let format = match artwork::sniff(&art.bytes)? {
                artwork::Format::Png => ImageFormat::Png,
                artwork::Format::Jpeg => ImageFormat::Jpeg,
            };
            self.cover = Some((
                art.id,
                Arc::new(Image::from_bytes(format, art.bytes.to_vec())),
            ));
        }
        self.cover.as_ref().map(|(_, image)| image.clone())
    }

    fn follow_volume(&mut self, snap: &Snapshot, window: &mut Window, cx: &mut Context<Self>) {
        let held = self
            .volume_touched
            .is_some_and(|t| t.elapsed() < VOLUME_HOLD);
        if let (false, Some(v)) = (held, snap.volume)
            && (self.volume.read(cx).value().end() - v).abs() > 0.005
        {
            self.volume.update(cx, |s, cx| s.set_value(v, window, cx));
        }
    }
}

/// How a round transport button looks.
struct Control {
    id: &'static str,
    icon: &'static str,
    size: f32,
    glyph: f32,
    fg: Hsla,
    fill: Option<Hsla>,
    hover: Hsla,
    /// Horizontal shift of the glyph, to look optically centred.
    nudge: f32,
}

fn control(spec: Control, enabled: bool) -> Stateful<Div> {
    let Control {
        id,
        icon,
        size,
        glyph,
        fg,
        fill,
        hover,
        nudge,
    } = spec;
    div()
        .id(id)
        .flex()
        .flex_none()
        .items_center()
        .justify_center()
        .size(px(size))
        .rounded_full()
        .when_some(fill, |d, f| d.bg(f))
        .when(enabled, |d| d.cursor_pointer().hover(move |s| s.bg(hover)))
        .when(!enabled, |d| d.opacity(0.35))
        .child(
            svg()
                .path(icon)
                .size(px(glyph))
                .ml(px(nudge))
                .text_color(fg),
        )
}

/// Colour of a checklist row's state: the same green, amber and red as the status light, so the
/// window and the taskbar badge say the same thing. They do not come from the cover: a green
/// cover must never look like a green light.
fn state_color(state: CheckState, off: Hsla) -> Hsla {
    match state {
        CheckState::Ok => status_color(Light::Green),
        CheckState::Wait => status_color(Light::Amber),
        CheckState::Bad => status_color(Light::Red),
        CheckState::Off => off,
    }
}

fn status_color(light: Light) -> Hsla {
    let [r, g, b] = light.rgb();
    rgb(((r as u32) << 16) | ((g as u32) << 8) | b as u32).into()
}

/// The big verdict: a beacon in the light's colour, the headline, and the first thing to fix.
fn verdict_view(verdict: &Verdict, muted: Hsla) -> Div {
    let color = status_color(verdict.light);
    div()
        .flex()
        .items_center()
        .gap(px(16.))
        .child(
            div()
                .flex()
                .flex_none()
                .items_center()
                .justify_center()
                .size(px(44.))
                .rounded_full()
                .bg(color.opacity(0.2))
                .child(div().size(px(22.)).rounded_full().bg(color)),
        )
        .child(
            div()
                .flex()
                .flex_col()
                .flex_1()
                .min_w_0()
                .gap(px(4.))
                .child(
                    div()
                        .font_family(DISPLAY)
                        .text_size(px(38.))
                        .line_height(relative(1.0))
                        .text_color(color)
                        .child(verdict.title),
                )
                .child(
                    div()
                        .text_size(px(13.))
                        .text_color(muted)
                        .line_clamp(2)
                        .child(verdict.hint.clone()),
                ),
        )
}

/// One row of the checklist: a state glyph, what is checked, and what is true right now.
fn check_row(check: &Check, p: Palette) -> Div {
    let color = state_color(check.state, col(p.muted));
    let icon = match check.state {
        CheckState::Ok => "icons/check.svg",
        CheckState::Wait => "icons/ellipsis.svg",
        CheckState::Bad => "icons/x.svg",
        CheckState::Off => "icons/minus.svg",
    };
    div()
        .flex()
        .items_center()
        .gap(px(12.))
        .px(px(14.))
        .min_h(px(34.))
        .py(px(3.))
        .child(
            div()
                .flex()
                .flex_none()
                .items_center()
                .justify_center()
                .size(px(20.))
                .rounded_full()
                .bg(color.opacity(0.18))
                .child(svg().path(icon).size(px(12.)).text_color(color)),
        )
        .child(
            div()
                .flex_none()
                .w(px(76.))
                .text_size(px(11.))
                .text_color(col(p.muted))
                .child(check.label.to_uppercase()),
        )
        .child(
            div()
                .flex_1()
                .min_w_0()
                .line_clamp(2)
                .text_size(px(13.))
                .text_color(if check.state == CheckState::Off {
                    col(p.muted)
                } else {
                    col(p.ink)
                })
                .child(check.detail.clone()),
        )
}

/// A thin rule between sections of the window.
fn separator(p: Palette) -> Div {
    div().h(px(1.)).flex_none().bg(col(p.muted).opacity(0.25))
}

/// The listening session as the server reports it: its own section between the signals and the
/// player, closed by separators. The state in its colour, then what it is about in full (it wraps
/// to two lines, nothing is cut to an ellipsis on a normal name). Fixed height, like the rest.
fn session_section(view: &SessionView, p: Palette) -> Div {
    let color = state_color(view.state, col(p.ink));
    div()
        .flex()
        .flex_col()
        .flex_none()
        .gap(px(4.))
        .h(px(84.))
        .child(
            div()
                .flex()
                .items_center()
                .justify_between()
                .text_size(px(11.))
                .text_color(col(p.muted))
                .child("LISTENING SESSION")
                .children(
                    view.position
                        .as_ref()
                        .map(|n| div().text_color(col(p.ink)).child(format!("TRACK {n}"))),
                ),
        )
        .child(
            div()
                .font_family(DISPLAY)
                .text_size(px(24.))
                .line_height(relative(1.0))
                .text_color(color)
                .child(view.headline),
        )
        .child(
            div()
                .line_clamp(2)
                .text_size(px(13.))
                .text_color(col(p.ink))
                .child(view.subtitle.clone()),
        )
}

/// A small outlined action in the footer.
fn action(id: &'static str, label: &'static str, p: Palette) -> Stateful<Div> {
    div()
        .id(id)
        .flex()
        .flex_none()
        .items_center()
        .px(px(12.))
        .h(px(28.))
        .rounded(px(4.))
        .border_1()
        .border_color(col(p.accent))
        .text_color(col(p.accent))
        .cursor_pointer()
        .hover(|s| s.bg(col(p.surface)))
        .child(label)
}

impl Render for NowPlaying {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let snap = lock(&self.shared).clone();
        let remote = lock(&self.remote).clone();
        let now = Instant::now();
        let p = Palette::from_tint(snap.artwork.as_ref().map(|a| a.tint));
        self.apply_theme(p, cx);
        self.follow_volume(&snap, window, cx);
        let cover = self.cover_image(snap.artwork.as_ref());

        let enabled = snap.can_control();
        let playing = snap.playback == player::Playback::Playing;

        let send = |command: fn() -> Command| {
            let commands = self.commands.clone();
            cx.listener(move |_, _, _, _| {
                let _ = commands.send(Request::local(command()));
            })
        };

        // The point of the window: is the link good, and if not, what to fix.
        let mut verdict = status::verdict(&snap, &remote, now);
        let checklist = div()
            .flex()
            .flex_col()
            .flex_none()
            .py(px(4.))
            .rounded(px(6.))
            .bg(col(p.surface))
            .children(
                status::checks(&snap, &remote, now)
                    .iter()
                    .map(|c| check_row(c, p)),
            );

        // What plays: the cover, the track, the artist, and the album in full (up to two lines).
        let thumb = div()
            .flex_none()
            .size(px(88.))
            .rounded(px(4.))
            .overflow_hidden()
            .bg(col(p.surface))
            .children(cover.map(|image| img(image).size_full().object_fit(ObjectFit::Cover)));
        let (title, artist, album) = if enabled {
            (
                snap.title.to_uppercase(),
                Some(snap.artist.clone()),
                snap.album_line().map(str::to_string),
            )
        } else {
            ("Nothing playing".to_uppercase(), None, None)
        };
        let track = div()
            .flex()
            .flex_col()
            .flex_1()
            .min_w_0()
            .gap(px(4.))
            .child(
                div()
                    .font_family(DISPLAY)
                    .text_size(px(20.))
                    .line_height(relative(1.05))
                    .line_clamp(2)
                    .child(title),
            )
            .children(artist.map(|a| div().truncate().text_size(px(13.)).child(a)))
            .children(album.map(|a| {
                div()
                    .line_clamp(2)
                    .text_size(px(12.))
                    .text_color(col(p.muted))
                    .child(a)
            }));
        let now_playing = div()
            .flex()
            .flex_none()
            .items_center()
            .gap(px(14.))
            .h(px(92.))
            .child(thumb)
            .child(track);

        // The ruler.
        let progress = snap.progress();
        let mut ruler = div().relative().w_full().h(px(40.)).mt(px(10.));
        for t in ticks(snap.length) {
            let lit = t.fraction <= progress;
            let (top, height) = match t.kind {
                TickKind::Major => (0., 22.),
                TickKind::Minor => (8., 14.),
            };
            ruler = ruler.child(
                div()
                    .absolute()
                    .left(relative(t.fraction))
                    .top(px(top))
                    .w(px(1.5))
                    .h(px(height))
                    .bg(if lit {
                        col(p.accent)
                    } else {
                        col(p.muted).opacity(0.4)
                    }),
            );
            if let Some(minute) = t.label {
                ruler = ruler.child(
                    div()
                        .absolute()
                        .left(relative(t.fraction))
                        .top(px(26.))
                        .ml(px(-3.))
                        .text_size(px(10.))
                        .text_color(col(p.muted))
                        .child(minute.to_string()),
                );
            }
        }
        if !snap.length.is_zero() {
            ruler = ruler
                .child(
                    div()
                        .absolute()
                        .left(relative(progress))
                        .top(px(-2.))
                        .ml(px(-1.))
                        .w(px(2.))
                        .h(px(26.))
                        .bg(col(p.ink)),
                )
                .child(
                    div()
                        .absolute()
                        .left(relative(progress))
                        .top(px(-8.))
                        .ml(px(-4.))
                        .size(px(8.))
                        .rounded_full()
                        .bg(col(p.ink)),
                );
        }
        let timeline =
            div()
                .flex()
                .flex_col()
                .h(px(62.))
                .flex_none()
                .when(!snap.length.is_zero(), |d| {
                    d.child(
                        div()
                            .flex()
                            .justify_between()
                            .text_size(px(12.))
                            .child(div().child(format_time(snap.position)))
                            .child(
                                div()
                                    .text_color(col(p.muted))
                                    .child(format_time(snap.length)),
                            ),
                    )
                    .child(ruler)
                });

        // Spotify's sound right now: a line that stays put and moves with it, in a small box of its own.
        let trace = lock(&self.scope).trace(TRACE_POINTS, now);
        let (line, baseline) = (col(p.accent), col(p.muted).opacity(0.3));
        let wave = div()
            .flex_none()
            .h(px(36.))
            .px(px(8.))
            .rounded(px(4.))
            .bg(col(p.surface))
            .child(
                canvas(
                    |bounds, _, _| bounds,
                    move |_, bounds, window, _| {
                        let middle = bounds.center().y;
                        let reach = bounds.size.height * 0.42;
                        let across = |i: usize, y| {
                            point(
                                bounds.left()
                                    + bounds.size.width * (i as f32 / (TRACE_POINTS - 1) as f32),
                                y,
                            )
                        };

                        let mut rule = PathBuilder::stroke(px(1.));
                        rule.move_to(across(0, middle));
                        rule.line_to(across(TRACE_POINTS - 1, middle));
                        if let Ok(path) = rule.build() {
                            window.paint_path(path, baseline);
                        }

                        let mut wave = PathBuilder::stroke(px(1.5));
                        for (i, level) in trace.iter().enumerate() {
                            let at = across(i, middle - reach * *level);
                            if i == 0 {
                                wave.move_to(at);
                            } else {
                                wave.line_to(at);
                            }
                        }
                        if let Ok(path) = wave.build() {
                            window.paint_path(path, line);
                        }
                    },
                )
                .size_full(),
            );

        // Transport and volume on one row.
        let hover = col(p.surface);
        let button = |id, icon, size, glyph, fg, fill, hover, nudge| {
            control(
                Control {
                    id,
                    icon,
                    size,
                    glyph,
                    fg,
                    fill,
                    hover,
                    nudge,
                },
                enabled,
            )
        };
        let controls = div()
            .flex()
            .flex_none()
            .items_center()
            .gap(px(10.))
            .child(
                button(
                    "previous",
                    "icons/skip-back.svg",
                    32.,
                    16.,
                    col(p.ink),
                    None,
                    hover,
                    0.,
                )
                .on_click(send(|| Command::Previous)),
            )
            .child(
                button(
                    "toggle",
                    if playing {
                        "icons/pause.svg"
                    } else {
                        "icons/play.svg"
                    },
                    44.,
                    18.,
                    col(p.on_accent),
                    Some(col(p.accent)),
                    col(p.accent).opacity(0.85),
                    // A play triangle's weight sits left of its box; shift it right to look centred.
                    if playing { 0. } else { 2. },
                )
                .on_click(send(|| Command::TogglePlayPause)),
            )
            .child(
                button(
                    "next",
                    "icons/skip-forward.svg",
                    32.,
                    16.,
                    col(p.ink),
                    None,
                    hover,
                    0.,
                )
                .on_click(send(|| Command::Next)),
            );
        let volume = div()
            .flex()
            .flex_1()
            .min_w_0()
            .items_center()
            .gap(px(8.))
            .child(
                svg()
                    .path("icons/volume-2.svg")
                    .size(px(16.))
                    .text_color(col(p.muted)),
            )
            .child(
                div().flex_1().child(
                    Slider::new(&self.volume)
                        .bg(col(p.accent))
                        .text_color(col(p.ink))
                        .disabled(!enabled || snap.volume.is_none()),
                ),
            );
        let transport = div()
            .flex()
            .flex_none()
            .items_center()
            .gap(px(16.))
            .child(controls)
            .child(volume);

        // What went wrong with the last local command, if anything.
        let problem = snap
            .notice
            .clone()
            .map(|n| format!("Last action failed: {n}"));
        let notice = div()
            .h(px(16.))
            .flex_none()
            .text_size(px(12.))
            .text_color(col(p.warn))
            .children(problem);

        // Footer: only the actions the link needs, and the server field while it is being edited.
        let needs_sign_in = matches!(remote.link, Link::Unauthorized);
        let signing_in = matches!(remote.link, Link::SigningIn);
        let local_only = matches!(remote.link, Link::Disabled) && self.remote_handle.is_none();
        let editing = local_only && self.editing_server;
        let enrolled = matches!(
            remote.link,
            Link::Connected | Link::Connecting | Link::Offline { .. }
        );
        let toggle_editor = |this: &mut Self, cx: &mut Context<Self>| {
            this.editing_server = !this.editing_server;
            this.server_error = None;
            cx.notify();
        };
        let open_editor = cx.listener(move |this, _, _, cx| toggle_editor(this, cx));
        let close_editor = cx.listener(move |this, _, _, cx| toggle_editor(this, cx));
        let connect = cx.listener(|this, _, _, cx| this.connect_server(cx));
        let sign_in = cx.listener(|this, _, _, _| {
            if let Some(handle) = &this.remote_handle {
                handle.sign_in();
            }
        });
        let change_server = cx.listener(|this, _, _, cx| this.change_server(cx));
        let cancel_sign_in = cx.listener(|this, _, _, _| {
            if let Some(handle) = &this.remote_handle {
                handle.cancel_sign_in();
            }
        });
        let sign_out = cx.listener(|this, _, _, _| {
            if let Some(handle) = &this.remote_handle {
                handle.sign_out();
            }
        });
        // The address field has no room for its error: it replaces the verdict's hint.
        let hint_color = match (&self.server_error, editing) {
            (Some(error), true) => {
                verdict.hint = error.clone();
                col(p.warn)
            }
            _ => col(p.muted),
        };
        // One fixed row, so the window never changes height: the actions, or the address field.
        let footer = div()
            .flex()
            .flex_none()
            .items_center()
            .justify_end()
            .gap(px(8.))
            .h(px(52.))
            .px(px(24.))
            .border_t_1()
            .border_color(col(p.muted).opacity(0.25))
            .text_size(px(12.))
            .text_color(col(p.muted))
            .when(editing, |d| {
                d.child(div().flex_1().child(Input::new(&self.server_input)))
                    .child(
                        div()
                            .id("connect")
                            .flex_none()
                            .px(px(12.))
                            .h(px(28.))
                            .flex()
                            .items_center()
                            .rounded(px(4.))
                            .bg(col(p.accent))
                            .text_color(col(p.on_accent))
                            .cursor_pointer()
                            .hover(|s| s.opacity(0.85))
                            .on_click(connect)
                            .child("Connect"),
                    )
            })
            .when(!editing && self.remote_handle.is_some(), |d| {
                d.child(
                    div()
                        .id("change-server")
                        .px(px(4.))
                        .py(px(2.))
                        .rounded(px(4.))
                        .cursor_pointer()
                        .hover(|s| s.text_color(col(p.ink)).bg(col(p.surface)))
                        .on_click(change_server)
                        .child("Change server"),
                )
            })
            .when(!editing && enrolled, |d| {
                d.child(
                    div()
                        .id("sign-out")
                        .px(px(4.))
                        .py(px(2.))
                        .rounded(px(4.))
                        .cursor_pointer()
                        .hover(|s| s.text_color(col(p.ink)).bg(col(p.surface)))
                        .on_click(sign_out)
                        .child("Sign out"),
                )
            })
            .when(signing_in, |d| {
                d.child(action("cancel-sign-in", "Cancel", p).on_click(cancel_sign_in))
            })
            .when(!editing && needs_sign_in, |d| {
                d.child(action("sign-in", "Sign in", p).on_click(sign_in))
            })
            .when(local_only && editing, |d| {
                d.child(
                    div()
                        .id("connect-server")
                        .flex()
                        .flex_none()
                        .items_center()
                        .justify_center()
                        .size(px(28.))
                        .rounded(px(4.))
                        .cursor_pointer()
                        .hover(|s| s.bg(col(p.surface)))
                        .on_click(close_editor)
                        .child(
                            svg()
                                .path("icons/x.svg")
                                .size(px(14.))
                                .text_color(col(p.muted)),
                        ),
                )
            })
            .when(local_only && !editing, |d| {
                d.child(action("connect-server", "Connect to server", p).on_click(open_editor))
            });

        div()
            .size_full()
            .flex()
            .flex_col()
            .bg(linear_gradient(
                180.,
                linear_color_stop(col(p.bg), 0.),
                linear_color_stop(col(p.bg_end), 1.),
            ))
            .text_color(col(p.ink))
            .font_family(MONO)
            .child(
                // Nothing clickable in here: Windows treats the whole bar as the window caption.
                TitleBar::new().child(
                    div()
                        .text_size(px(11.))
                        .text_color(col(p.muted))
                        .child("PREMIÈRE ÉCOUTE"),
                ),
            )
            .child(
                div()
                    .flex()
                    .flex_col()
                    .flex_1()
                    .min_h_0()
                    .gap(px(14.))
                    .px(px(24.))
                    .pt(px(8.))
                    .pb(px(14.))
                    .child(verdict_view(&verdict, hint_color))
                    .child(checklist)
                    .child(separator(p))
                    .child(session_section(&status::session_view(&remote), p))
                    .child(separator(p))
                    .child(now_playing)
                    .child(timeline)
                    .child(wave)
                    .child(transport)
                    .child(notice),
            )
            .child(footer)
    }
}

/// Holds the dev-only preview switches read from `PLAYER_UI_PREVIEW` (comma separated):
/// a remote state (`connected`, `connecting`, `offline`, `unauthorized`, `failed`), `idle`
/// (nothing playing), `sample` (a fixed playing track with long names), `no-session` and `preparing`
/// (with `connected`: what the server says about the session) and `connect` (server field open).
pub struct Preview {
    pub remote: Option<RemoteStatus>,
    pub snapshot: Option<Snapshot>,
    /// Start with the server field open (`connect`).
    pub editing_server: bool,
}

pub fn preview() -> Preview {
    let raw = std::env::var("PLAYER_UI_PREVIEW").unwrap_or_default();
    let now = Instant::now();
    let has = |name: &str| raw.split(',').any(|k| k.trim() == name);
    let snapshot = if has("sample") {
        Some(Snapshot {
            running: true,
            playback: player::Playback::Playing,
            title: "Everything Is Recorded By Night".into(),
            artist: "Sampha and The Avalanches".into(),
            album: "A Long Album Title (Deluxe Edition)".into(),
            position: Duration::from_secs(95),
            length: Duration::from_secs(262),
            volume: Some(0.6),
            ..Snapshot::default()
        })
    } else if has("idle") {
        Some(Snapshot::not_running())
    } else {
        None
    };
    let mut remote = raw
        .split(',')
        .find_map(|k| RemoteStatus::preview(k.trim(), now));
    // `no-session` and `preparing` change what a previewed live link says about the session.
    if let Some(info) = remote.as_mut().and_then(|r| r.session.as_mut()) {
        if has("no-session") {
            *info = SessionInfo {
                state: SessionState::None,
                source: None,
                name: None,
                track_number: None,
                track_count: None,
            };
        } else if has("preparing") {
            info.state = SessionState::Preparing;
            info.track_number = None;
        }
    }
    Preview {
        remote,
        snapshot,
        editing_server: has("connect"),
    }
}

/// Keeps a previewed live link sending, so the window does not report it as stale after 5 s.
pub fn keep_link_fresh(remote: Arc<Mutex<RemoteStatus>>) {
    std::thread::spawn(move || {
        loop {
            {
                let mut status = lock(&remote);
                if matches!(status.link, Link::Connected) {
                    status.exchange.last_snapshot_at = Some(Instant::now());
                    status.heard_at = Some(Instant::now());
                }
            }
            std::thread::sleep(Duration::from_secs(1));
        }
    });
}

/// Feeds the scope with a believable pulse, for previews without Spotify.
pub fn fake_sound(scope: Arc<Mutex<Scope>>) {
    std::thread::spawn(move || {
        let start = Instant::now();
        let mut sample = 0u64;
        loop {
            let t = start.elapsed().as_secs_f32();
            let beat = (t * 2.2 * std::f32::consts::TAU).sin().abs().powf(3.0);
            let level = 0.12 + 0.6 * beat * (0.55 + 0.35 * (t * 0.7).sin());
            let samples: Vec<f32> = (0..1_200)
                .map(|_| {
                    let x = sample as f32 / 48_000.0 * std::f32::consts::TAU;
                    sample += 1;
                    level
                        * (0.6 * (x * 140.0).sin()
                            + 0.3 * (x * 420.0).sin()
                            + 0.1 * (x * 1300.0).sin())
                })
                .collect();
            lock(&scope).push(&samples, Instant::now());
            std::thread::sleep(Duration::from_millis(25));
        }
    });
}
