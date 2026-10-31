// Release builds are GUI programs: no console window next to the app.
#![cfg_attr(all(windows, not(debug_assertions)), windows_subsystem = "windows")]

mod artwork;
#[cfg(windows)]
mod capture;
mod ending;
mod identity;
#[cfg(windows)]
mod instance;
mod light;
mod log;
mod player;
mod remote;
mod remote_status;
#[cfg(windows)]
mod smtc;
mod start;
mod status;
mod supervise;
#[cfg(windows)]
mod taskbar;
#[cfg(windows)]
mod tray;
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

/// Development only, built with `--features dev-tools`: `PLAYER_DEV_PLAY=spotify:track:<id>` plays
/// that track at start, as the backend would command it (`PLAYER_DEV_TRACK=<n>` adds its position
/// in its album, `PLAYER_DEV_DURATION_MS=<ms>` its exact length), and `PLAYER_DEV_SESSION=1` behaves as if the backend said a session is running.
#[cfg(feature = "dev-tools")]
fn dev_tools(commands: &std::sync::mpsc::Sender<player::Request>) {
    if let Ok(uri) = std::env::var("PLAYER_DEV_PLAY") {
        let number = std::env::var("PLAYER_DEV_TRACK")
            .ok()
            .and_then(|n| n.parse::<u32>().ok());
        let duration = std::env::var("PLAYER_DEV_DURATION_MS")
            .ok()
            .and_then(|n| n.parse::<u64>().ok())
            .map(std::time::Duration::from_millis);
        let command = if number.is_some() || duration.is_some() {
            player::Command::PlayTrack {
                uri,
                number,
                duration,
            }
        } else {
            player::Command::PlayUri(uri)
        };
        let _ = commands.send(player::Request::local(command));
    }
    if std::env::var_os("PLAYER_DEV_SESSION").is_some() {
        std::thread::spawn(|| {
            loop {
                player::session_running().store(true, std::sync::atomic::Ordering::Relaxed);
                std::thread::sleep(std::time::Duration::from_millis(300));
            }
        });
    }
}

fn main() {
    // Previews never link to the backend, so they cannot steal its one connection.
    #[cfg(windows)]
    if std::env::var_os("PLAYER_UI_PREVIEW").is_none() && !instance::first() {
        return;
    }
    log::init();
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
        #[cfg(feature = "dev-tools")]
        dev_tools(&commands);
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
                |decision, message| {
                    log::warn(format!("audio-capture crashed: {message} ({decision:?})"))
                },
                move || capture::run(scope.clone()),
            );
            let shared = shared.clone();
            supervise::supervise(
                "player-worker",
                supervise::Policy::default(),
                |decision, message| {
                    log::warn(format!("player-worker crashed: {message} ({decision:?})"))
                },
                move || {
                    player::run_with(
                        smtc::Smtc::default(),
                        &rx,
                        shared.clone(),
                        ui::POLL,
                        player::session_running(),
                    )
                },
            );
        }
        if previewing {
            ui::fake_sound(scope.clone());
            ui::keep_link_fresh(remote.clone());
        }
        #[cfg(not(windows))]
        {
            drop(rx);
            *player::lock(&shared) = Snapshot::failed("only Windows is supported");
        }

        let options = WindowOptions {
            window_bounds: Some(WindowBounds::Windowed(Bounds::centered(
                None,
                size(px(400.), px(730.)),
                cx,
            ))),
            // Fixed: everything in the window has a fixed height, so a bigger window is only empty space.
            is_resizable: false,
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
