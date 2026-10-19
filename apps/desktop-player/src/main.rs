// Release builds are GUI programs: no console window next to the app.
#![cfg_attr(all(windows, not(debug_assertions)), windows_subsystem = "windows")]

mod artwork;
#[cfg(windows)]
mod capture;
mod identity;
mod player;
mod remote;
mod remote_status;
#[cfg(windows)]
mod smtc;
mod supervise;
mod ui;
#[cfg(windows)]
mod volume;
mod waveform;

use gpui_kit::component::TitleBar;
use gpui_kit::*;
use player::Snapshot;
use remote_status::RemoteStatus;
use std::borrow::Cow;
use std::sync::{Arc, Mutex};
use ui::NowPlaying;
use waveform::Scope;

fn main() {
    application().with_assets(ui::assets::AppAssets).run(|cx| {
        init(cx);
        cx.text_system()
            .add_fonts(vec![
                Cow::Borrowed(include_bytes!("../assets/fonts/Anton-Regular.ttf").as_slice()),
                Cow::Borrowed(include_bytes!("../assets/fonts/DMMono-Regular.ttf").as_slice()),
                Cow::Borrowed(include_bytes!("../assets/fonts/DMMono-Medium.ttf").as_slice()),
            ])
            .expect("embedded fonts load");

        let shared = Arc::new(Mutex::new(Snapshot::default()));
        let remote = Arc::new(Mutex::new(RemoteStatus::default()));
        let scope = Arc::new(Mutex::new(Scope::default()));
        let (commands, rx) = player::channel();
        let preview = ui::preview();

        if let Some(status) = preview.remote {
            *player::lock(&remote) = status;
        }
        let previewing = preview.snapshot.is_some();
        let editing_server = preview.editing_server;
        if let Some(snapshot) = preview.snapshot {
            *player::lock(&shared) = snapshot;
        }
        // The server is PLAYER_HUB_URL, else the address saved from the window, else the build's default.
        let remote_handle = if previewing {
            None
        } else {
            match remote::Settings::configured() {
                Ok(settings) => Some(remote::start(
                    settings,
                    shared.clone(),
                    commands.clone(),
                    remote.clone(),
                )),
                Err(message) => {
                    player::lock(&remote).link = remote_status::Link::Failed(message);
                    None
                }
            }
        };
        #[cfg(windows)]
        if !previewing {
            let scope = scope.clone();
            supervise::supervise(
                "audio-capture",
                supervise::Policy::default(),
                |_, _| {},
                move || capture::run(scope.clone()),
            );
            let shared = shared.clone();
            supervise::supervise(
                "player-worker",
                supervise::Policy::default(),
                |_, _| {},
                move || player::run(smtc::Smtc::default(), &rx, shared.clone(), ui::POLL),
            );
        }
        if previewing {
            ui::fake_sound(scope.clone());
        }
        #[cfg(not(windows))]
        {
            drop(rx);
            *player::lock(&shared) = Snapshot::failed("only Windows is supported");
        }

        let options = WindowOptions {
            window_bounds: Some(WindowBounds::Windowed(Bounds::centered(
                None,
                size(px(400.), px(840.)),
                cx,
            ))),
            window_min_size: Some(size(px(360.), px(660.))),
            ..TitleBar::window_options()
        };
        open_window(options, cx, |window, cx| {
            cx.new(|cx| {
                NowPlaying::new(window, cx, shared, remote, scope, commands, remote_handle)
                    .editing_server(editing_server)
            })
        })
        .expect("Failed to open window");
    });
}
