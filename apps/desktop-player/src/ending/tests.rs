use super::*;
use crate::player::{Backend, Command, Request, run};
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};

fn track(title: &str, position: u64, length: u64, playback: Playback) -> Snapshot {
    Snapshot {
        running: true,
        title: title.into(),
        artist: "Artist".into(),
        album: "Album".into(),
        uri: Some(format!("spotify:track:{title}")),
        position: Duration::from_secs(position),
        length: Duration::from_secs(length),
        playback,
        volume: Some(0.5),
        ..Snapshot::default()
    }
}

/// An `Ending` that has just begun on "Song" (180 s), at `t0`.
fn begun(t0: Instant) -> Ending {
    let mut e = Ending::default();
    e.remember(&track("Song", 178, 180, Playback::Playing));
    e.begin(t0);
    e
}

fn ms(n: u64) -> Duration {
    Duration::from_millis(n)
}

#[test]
fn nothing_to_hide_before_a_track_was_followed() {
    let t0 = Instant::now();
    let mut e = Ending::default();
    e.begin(t0);
    assert!(!e.active());
    let mut real = track("Other", 5, 100, Playback::Playing);
    assert!(!e.apply(&mut real, t0, false));
    assert_eq!(real.title, "Other");
}

#[test]
fn the_track_is_reported_playing_at_its_very_end_right_after_the_pause() {
    // The backend decides a track ended when it sees it playing at 99% or more: the snapshot it
    // gets must show that, even though the pause already happened.
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = track("Song", 179, 180, Playback::Paused);
    e.apply(&mut real, t0 + ms(300), false);
    assert_eq!(real.title, "Song");
    assert_eq!(real.playback, Playback::Playing);
    assert_eq!(real.position, real.length);
}

#[test]
fn then_it_is_reported_paused_at_its_end_like_a_track_that_stopped() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = track("Song", 179, 180, Playback::Paused);
    e.apply(&mut real, t0 + Duration::from_secs(2), false);
    assert_eq!(real.playback, Playback::Paused);
    assert_eq!(real.position, Duration::from_secs(180));
    assert_eq!(real.title, "Song");
    assert_eq!(real.uri.as_deref(), Some("spotify:track:Song"));
}

#[test]
fn the_hold_is_longer_than_a_snapshot_interval() {
    // One snapshot goes out every second: the "playing at the end" state must last longer.
    assert!(HOLD > Duration::from_secs(1));
}

#[test]
fn a_next_track_that_starts_anyway_is_hidden_and_paused_again() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut leaked = track("Next", 0, 200, Playback::Playing);
    let again = e.apply(&mut leaked, t0 + ms(300), false);
    assert!(again, "the leaked track must be paused");
    assert_eq!(leaked.title, "Song", "nobody sees the next track");
}

#[test]
fn pausing_again_is_paced_and_limited() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut times = 0;
    let mut t = t0;
    for _ in 0..100 {
        t += ms(100);
        if t - t0 >= LEAK_WINDOW {
            break;
        }
        let mut leaked = track("Next", 0, 200, Playback::Playing);
        if e.apply(&mut leaked, t, false) {
            times += 1;
        }
    }
    assert!(times >= 2, "it must insist, got {times}");
    assert!(times <= MAX_PAUSES as usize, "but not forever, got {times}");
}

#[test]
fn the_user_playing_later_is_left_alone() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = track("Next", 3, 200, Playback::Playing);
    let again = e.apply(&mut real, t0 + LEAK_WINDOW + ms(1), false);
    assert!(!again);
    assert_eq!(real.title, "Next", "what plays is reported as it is");
    assert!(!e.active());
}

#[test]
fn a_paused_spotify_on_another_track_stays_hidden_for_as_long_as_it_is_paused() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = track("Next", 0, 200, Playback::Paused);
    e.apply(&mut real, t0 + Duration::from_secs(600), false);
    assert_eq!(
        (real.title.as_str(), real.playback),
        ("Song", Playback::Paused)
    );
    assert!(e.active());
}

#[test]
fn closing_spotify_ends_the_hiding() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = Snapshot::not_running();
    assert!(!e.apply(&mut real, t0 + ms(500), false));
    assert!(!e.active());
    assert!(!real.running);
}

#[test]
fn the_same_track_still_playing_is_only_paused_again_when_that_is_safe() {
    // A toggle would resume a track that did pause, so it is only used when it cannot misfire.
    let t0 = Instant::now();
    let still = || track("Song", 179, 180, Playback::Playing);
    let mut e = begun(t0);
    assert!(!e.apply(&mut still(), t0 + ms(400), false));
    let mut e = begun(t0);
    assert!(e.apply(&mut still(), t0 + ms(400), true));
}

#[test]
fn a_new_command_clears_everything() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    e.clear();
    assert!(!e.active());
    let mut real = track("Next", 1, 100, Playback::Playing);
    assert!(!e.apply(&mut real, t0 + ms(10), false));
    assert_eq!(real.title, "Next");
}

#[test]
fn the_volume_shown_is_the_real_one() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut real = Snapshot {
        volume: Some(0.9),
        ..track("Song", 179, 180, Playback::Paused)
    };
    e.apply(&mut real, t0 + ms(100), false);
    assert_eq!(real.volume, Some(0.9));
}

#[test]
fn the_loop_wakes_up_often_enough_only_while_it_is_hiding() {
    let t0 = Instant::now();
    assert_eq!(Ending::default().wake_in(t0), None);
    let e = begun(t0);
    assert_eq!(e.wake_in(t0 + ms(100)), Some(WATCH));
    assert_eq!(e.wake_in(t0 + LEAK_WINDOW + ms(1)), None);
}

/// A Spotify that, once the commanded track reaches its end, ignores the first pause and moves on
/// to the next album track, then obeys the second pause.
struct Stubborn {
    state: Arc<Mutex<Spotify>>,
}

#[derive(Default)]
struct Spotify {
    played: bool,
    reads: u32,
    pauses: u32,
    leaked: bool,
}

impl Backend for Stubborn {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        let mut s = self.state.lock().unwrap();
        s.reads += 1;
        Ok(if !s.played {
            track("Old", 50, 100, Playback::Playing)
        } else if s.pauses == 0 && !s.leaked && s.reads < 6 {
            track("Song", 100, 180, Playback::Playing)
        } else if s.pauses == 0 {
            // The last second: the loop pauses now, but Spotify carries on with the album.
            s.leaked = true;
            track("Song", 179, 180, Playback::Playing)
        } else if s.pauses == 1 {
            track("Next", 0, 200, Playback::Playing)
        } else {
            track("Next", 0, 200, Playback::Paused)
        })
    }
    fn toggle_play_pause(&mut self) -> Result<(), String> {
        Ok(())
    }
    fn pause(&mut self) -> Result<(), String> {
        self.state.lock().unwrap().pauses += 1;
        Ok(())
    }
    fn next(&mut self) -> Result<(), String> {
        Ok(())
    }
    fn previous(&mut self) -> Result<(), String> {
        Ok(())
    }
    fn set_volume(&mut self, _: f32) -> Result<(), String> {
        Ok(())
    }
    fn play_uri(&mut self, _: &str) -> Result<(), String> {
        self.state.lock().unwrap().played = true;
        Ok(())
    }
}

#[test]
fn run_pauses_again_when_spotify_moves_on_and_nobody_sees_the_next_track() {
    let state = Arc::new(Mutex::new(Spotify::default()));
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let handle = {
        let (state, shared) = (state.clone(), shared.clone());
        std::thread::spawn(move || run(Stubborn { state }, &rx, shared, Duration::from_millis(5)))
    };
    tx.send(Request::local(Command::PlayUri("spotify:track:x".into())))
        .unwrap();

    let deadline = Instant::now() + Duration::from_secs(5);
    while state.lock().unwrap().pauses < 2 {
        assert!(
            Instant::now() < deadline,
            "the leaked track was not paused again"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    // Every snapshot published since the end is the commanded track, never the next one.
    for _ in 0..20 {
        let title = shared.lock().unwrap().title.clone();
        assert_ne!(
            title, "Next",
            "the next track leaked into the reported state"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    drop(tx);
    handle.join().unwrap();
}

#[test]
fn the_same_track_with_a_jittering_length_is_not_taken_for_a_leaked_next_track() {
    let t0 = Instant::now();
    let mut e = begun(t0);
    let mut same = Snapshot {
        length: Duration::from_millis(180_080),
        ..track("Song", 179, 180, Playback::Playing)
    };
    // Playing the commanded track again after the pause: only paused again when that is safe.
    assert!(!e.apply(&mut same, t0 + ms(400), false));
}
