use super::*;
use crate::player::{Backend, Playback};
use std::sync::{Arc, Mutex};

const LENGTH: u64 = 180;

/// A Spotify reproducing what was measured on a real client: asking for a track plays it from
/// 0:00, except the first track of the album that is already loaded, which just resumes what is
/// loaded. Skipping back goes to the previous track (from 3 s into a track at the latest) and
/// starts it playing, even when paused.
struct Spotify {
    log: Arc<Mutex<Vec<String>>>,
    /// Index of the current track in the loaded album, from 0.
    current: usize,
    position: u64,
    playing: bool,
    volume: Option<f32>,
    /// Whether the player can tell the track number (a context that is not an album cannot).
    numbered: bool,
    /// The track the commanded uri stands for, from 0.
    requested: usize,
    /// Starts nothing: Spotify ignores the command.
    deaf: bool,
    /// Skips that do nothing.
    stuck: bool,
    /// Moves on to the next track by itself the first time it is paused: the track it resumed was
    /// in its last second.
    drifts: bool,
    /// How many skips back are ignored before they work again.
    flaky: u32,
    /// Where Spotify goes when the first track of the album is asked for, whatever plays: the
    /// album's last track and position.
    resume_to: Option<(usize, u64)>,
    ticks: u64,
}

impl Spotify {
    fn on(current: usize, position: u64, requested: usize) -> (Self, Arc<Mutex<Vec<String>>>) {
        let log = Arc::new(Mutex::new(Vec::new()));
        (
            Self {
                log: log.clone(),
                current,
                position,
                playing: false,
                volume: Some(0.8),
                numbered: true,
                requested,
                deaf: false,
                stuck: false,
                drifts: false,
                flaky: 0,
                resume_to: None,
                ticks: 0,
            },
            log,
        )
    }

    fn shot(&self) -> Snapshot {
        Snapshot {
            running: true,
            title: format!("Track {}", self.current + 1),
            artist: "Artist".into(),
            album: "Album".into(),
            track_number: self.numbered.then_some(self.current as u32 + 1),
            position: Duration::from_secs(self.position),
            length: Duration::from_secs(LENGTH),
            playback: if self.playing {
                Playback::Playing
            } else {
                Playback::Paused
            },
            volume: self.volume,
            ..Snapshot::default()
        }
    }

    fn note(&self, what: impl Into<String>) {
        self.log.lock().unwrap().push(what.into());
    }
}

impl Backend for Spotify {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        self.ticks += 1;
        Ok(self.shot())
    }
    fn toggle_play_pause(&mut self) -> Result<(), String> {
        self.playing = !self.playing;
        Ok(())
    }
    fn pause(&mut self) -> Result<(), String> {
        self.note("pause");
        if self.drifts {
            self.drifts = false;
            self.current += 1;
            self.position = 0;
        }
        self.playing = false;
        Ok(())
    }
    fn verifies_start(&self) -> bool {
        true
    }
    fn play(&mut self) -> Result<(), String> {
        self.note("play");
        self.playing = true;
        Ok(())
    }
    fn seek(&mut self, to: Duration) -> Result<(), String> {
        self.note(format!("seek {}", to.as_secs()));
        self.position = to.as_secs();
        Ok(())
    }
    fn next(&mut self) -> Result<(), String> {
        self.note("next");
        if self.stuck {
            return Ok(());
        }
        self.current += 1;
        self.position = 0;
        self.playing = true;
        Ok(())
    }
    fn previous(&mut self) -> Result<(), String> {
        self.note("previous");
        if self.stuck {
            return Ok(());
        }
        if self.flaky > 0 {
            self.flaky -= 1;
            return Ok(());
        }
        if self.position < 3 && self.current > 0 {
            self.current -= 1;
        }
        self.position = 0;
        self.playing = true;
        Ok(())
    }
    fn set_volume(&mut self, volume: f32) -> Result<(), String> {
        self.note(format!("volume {volume:.1}"));
        self.volume = Some(volume);
        Ok(())
    }
    fn play_uri(&mut self, _uri: &str) -> Result<(), String> {
        self.note("play_uri");
        if self.deaf {
            return Ok(());
        }
        self.playing = true;
        if self.requested != 0 {
            self.current = self.requested;
            self.position = 0;
        } else if let Some((track, position)) = self.resume_to {
            // The first track of an album: Spotify goes back to where the album was left.
            self.current = track;
            self.position = position;
        }
        // Otherwise the first track of the loaded album: Spotify resumes what is loaded.
        Ok(())
    }
}

fn run_start(spotify: &mut Spotify) -> (Result<(), String>, Vec<Snapshot>) {
    let before = spotify.shot();
    let mut published = Vec::new();
    spotify.playing = false; // the guard's `before`: what was loaded, paused
    let result = {
        let before = Snapshot {
            playback: Playback::Paused,
            ..before
        };
        start(
            spotify,
            "spotify:track:x",
            &before,
            &mut |s| published.push(s.clone()),
            &|_| {},
        )
    };
    (result, published)
}

fn snap(title: &str, position: u64, playback: Playback) -> Snapshot {
    Snapshot {
        running: true,
        title: title.into(),
        artist: "A".into(),
        length: Duration::from_secs(LENGTH),
        position: Duration::from_secs(position),
        playback,
        ..Snapshot::default()
    }
}

#[test]
fn a_different_track_starting_at_its_beginning_is_a_start() {
    let before = snap("Old", 100, Playback::Paused);
    assert_eq!(
        judge(&before, &snap("New", 0, Playback::Playing)),
        Verdict::Started
    );
    assert_eq!(
        judge(&before, &snap("New", 2, Playback::Playing)),
        Verdict::Started
    );
}

#[test]
fn the_same_track_back_at_the_start_is_a_restart() {
    let before = snap("Song", 27, Playback::Paused);
    assert_eq!(
        judge(&before, &snap("Song", 1, Playback::Playing)),
        Verdict::Started
    );
    assert_eq!(
        judge(&before, &snap("Song", 3, Playback::Playing)),
        Verdict::Started
    );
}

#[test]
fn the_same_track_going_on_where_it_was_is_not_the_commanded_one() {
    let before = snap("Song", 27, Playback::Paused);
    assert_eq!(
        judge(&before, &snap("Song", 28, Playback::Playing)),
        Verdict::Resumed
    );
    assert_eq!(
        judge(&before, &snap("Song", 60, Playback::Playing)),
        Verdict::Resumed
    );
}

#[test]
fn a_track_paused_near_its_start_that_plays_is_taken_as_started() {
    // Indistinguishable from a restart: not worth a fix that could do harm.
    let before = snap("Song", 1, Playback::Paused);
    assert_eq!(
        judge(&before, &snap("Song", 2, Playback::Playing)),
        Verdict::Started
    );
}

#[test]
fn a_track_that_starts_normally_needs_nothing_else() {
    let (mut s, log) = Spotify::on(2, 40, 7);
    let (result, _) = run_start(&mut s);
    assert_eq!(result, Ok(()));
    assert_eq!(s.current, 7);
    assert_eq!(*log.lock().unwrap(), vec!["play_uri"]);
}

#[test]
fn a_resume_of_the_first_track_of_the_album_is_fixed_by_going_back_to_it() {
    // On track 4, 40 s in; track 1 was asked for and Spotify went on with track 4.
    let (mut s, log) = Spotify::on(3, 40, 0);
    let (result, _) = run_start(&mut s);
    assert_eq!(result, Ok(()));
    assert_eq!(s.current, 0, "track 1 plays");
    assert!(s.position <= 3, "from its beginning, got {}", s.position);
    assert!(s.playing);
    let log = log.lock().unwrap();
    assert_eq!(
        log.iter().filter(|l| *l == "previous").count(),
        3,
        "{log:?}"
    );
}

#[test]
fn nothing_is_heard_of_the_fix_and_the_volume_comes_back() {
    let (mut s, log) = Spotify::on(3, 40, 0);
    run_start(&mut s).0.unwrap();
    let log = log.lock().unwrap();
    let mute = log.iter().position(|l| l == "volume 0.0").expect("muted");
    let first_skip = log.iter().position(|l| l == "previous").unwrap();
    assert!(mute < first_skip, "muted before the first skip: {log:?}");
    assert_eq!(
        log.last().map(String::as_str),
        Some("volume 0.8"),
        "{log:?}"
    );
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn a_resume_of_the_track_that_is_already_the_first_just_restarts_it() {
    let (mut s, log) = Spotify::on(0, 40, 0);
    let (result, _) = run_start(&mut s);
    assert_eq!(result, Ok(()));
    assert_eq!((s.current, s.position <= 3, s.playing), (0, true, true));
    assert!(!log.lock().unwrap().iter().any(|l| l == "previous"));
    assert!(log.lock().unwrap().iter().any(|l| l == "seek 0"));
}

#[test]
fn when_the_track_number_is_unknown_it_is_not_guessed() {
    let (mut s, _) = Spotify::on(3, 40, 0);
    s.numbered = false;
    let (result, _) = run_start(&mut s);
    assert!(result.unwrap_err().contains("track"), "a reason is given");
}

#[test]
fn a_spotify_that_does_not_move_gives_up_and_restores_the_volume() {
    let (mut s, _) = Spotify::on(3, 40, 0);
    s.stuck = true;
    let (result, _) = run_start(&mut s);
    assert!(result.is_err());
    assert_eq!(s.volume, Some(0.8), "never left muted");
}

#[test]
fn a_spotify_that_never_starts_playing_is_reported() {
    let (mut s, _) = Spotify::on(3, 40, 7);
    s.deaf = true;
    let (result, _) = run_start(&mut s);
    assert!(result.unwrap_err().contains("play"));
}

#[test]
fn a_spotify_without_a_volume_is_fixed_without_touching_it() {
    let (mut s, log) = Spotify::on(2, 40, 0);
    s.volume = None;
    run_start(&mut s).0.unwrap();
    assert!(!log.lock().unwrap().iter().any(|l| l.starts_with("volume")));
}

#[test]
fn what_is_seen_while_it_works_is_published() {
    let (mut s, _) = Spotify::on(3, 40, 0);
    let (_, published) = run_start(&mut s);
    assert!(
        !published.is_empty(),
        "the window and the backend keep seeing Spotify"
    );
}

#[test]
fn run_repairs_a_resumed_track_before_answering_and_then_guards_the_new_one() {
    use crate::player::{Command, Reply, Request, run};
    use std::sync::mpsc::channel;

    let (mut spotify, log) = Spotify::on(3, 40, 0);
    spotify.playing = false;
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let (request, reply) = Request::remote(
        Command::PlayUri("spotify:track:x".into()),
        Duration::from_secs(30),
    );
    let handle = {
        let shared = shared.clone();
        std::thread::spawn(move || run(spotify, &rx, shared, Duration::from_millis(5)))
    };
    tx.send(request).unwrap();
    // The answer comes once track 1 plays, not when the command was merely launched.
    assert_eq!(reply.recv_timeout(Duration::from_secs(10)), Ok(Reply::Done));
    assert_eq!(shared.lock().unwrap().title, "Track 1");
    drop(tx);
    handle.join().unwrap();
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
}

/// Plays back a script of snapshots, the last one for ever.
struct Scripted {
    script: Vec<Snapshot>,
    at: usize,
}

impl Backend for Scripted {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        let s = self.script[self.at.min(self.script.len() - 1)].clone();
        self.at += 1;
        Ok(s)
    }
    fn toggle_play_pause(&mut self) -> Result<(), String> {
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
        Ok(())
    }
}

#[test]
fn a_start_is_only_done_once_the_identity_of_the_track_is_stable() {
    let before = snap("Old", 193, Playback::Paused);
    // The new length arrives before the new title.
    let mixed = Snapshot {
        length: Duration::from_secs(243),
        ..snap("Old", 0, Playback::Playing)
    };
    let settled = Snapshot {
        length: Duration::from_secs(243),
        ..snap("New", 1, Playback::Playing)
    };
    let mut backend = Scripted {
        script: vec![mixed, settled],
        at: 0,
    };
    let mut seen = Vec::new();
    let result = start(
        &mut backend,
        "spotify:track:x",
        &before,
        &mut |s| seen.push(s.title.clone()),
        &|_| {},
    );
    assert_eq!(result, Ok(()));
    // It did not stop at the mixed-up snapshot: the settled one was published before it returned.
    assert_eq!(seen.last().map(String::as_str), Some("New"));
}

#[test]
fn a_track_whose_identity_never_settles_is_not_a_start() {
    let before = snap("Old", 193, Playback::Paused);
    let flicker = |title: &str| Snapshot {
        length: Duration::from_secs(243),
        ..snap(title, 0, Playback::Playing)
    };
    let script: Vec<Snapshot> = (0..400)
        .map(|i| flicker(if i % 2 == 0 { "A" } else { "B" }))
        .collect();
    let mut backend = Scripted { script, at: 0 };
    let result = start(
        &mut backend,
        "spotify:track:x",
        &before,
        &mut |_| {},
        &|_| {},
    );
    assert!(result.is_err());
}

#[test]
fn a_spotify_that_moves_on_by_itself_while_it_is_being_repaired_still_ends_on_track_1() {
    // Parked at the very end of track 3: resumed for a last second, it carries on to track 4.
    let (mut s, log) = Spotify::on(2, 179, 0);
    s.drifts = true;
    let (result, _) = run_start(&mut s);
    assert_eq!(result, Ok(()));
    assert_eq!((s.current, s.position <= 3, s.playing), (0, true, true));
    // It walked back from where Spotify really was (track 4), not from the track it first saw.
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn a_skip_back_is_only_made_from_the_start_of_a_track() {
    // Skipping back from later than 3 s into a track only restarts it.
    let (mut s, log) = Spotify::on(3, 90, 0);
    run_start(&mut s).0.unwrap();
    let log = log.lock().unwrap();
    let first_skip = log.iter().position(|l| l == "previous").unwrap();
    assert!(log[..first_skip].iter().any(|l| l == "seek 0"), "{log:?}");
}

#[test]
fn a_repair_that_fails_once_is_tried_again_from_where_spotify_is() {
    // The first skips are ignored: that attempt gives up, the next one works.
    let (mut s, log) = Spotify::on(3, 40, 0);
    s.flaky = 1;
    let (result, _) = run_start(&mut s);
    assert_eq!(result, Ok(()));
    assert_eq!((s.current, s.playing), (0, true));
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "play_uri")
            .count(),
        2,
        "the command was sent again"
    );
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn it_gives_up_after_the_second_attempt() {
    let (mut s, log) = Spotify::on(3, 40, 0);
    s.stuck = true;
    let (result, _) = run_start(&mut s);
    assert!(result.is_err());
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "play_uri")
            .count(),
        2
    );
    assert_eq!(s.volume, Some(0.8), "never left muted");
}

#[test]
fn a_spotify_that_does_not_play_at_all_is_not_retried() {
    // Nothing to repair: waiting longer would only make the answer late.
    let (mut s, log) = Spotify::on(3, 40, 7);
    s.deaf = true;
    let (result, _) = run_start(&mut s);
    assert!(result.is_err());
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "play_uri")
            .count(),
        1
    );
}

#[test]
fn a_track_parked_at_its_very_end_is_not_touched_before_the_command() {
    // Rewinding it would make a resume look like a clean restart: the repair copes instead.
    let (mut s, log) = Spotify::on(2, 179, 7);
    run_start(&mut s).0.unwrap();
    assert!(!log.lock().unwrap().iter().any(|l| l == "seek 0"));
}

#[test]
fn the_second_attempt_does_not_mistake_a_rewound_track_for_a_restart() {
    // The first attempt's own seek to 0:00 left the loaded track at its start; resumed again, it is
    // still not the commanded track.
    let (mut s, _) = Spotify::on(3, 40, 0);
    s.stuck = true;
    let (result, _) = run_start(&mut s);
    assert!(
        result.is_err(),
        "a Spotify that cannot go back is not a start"
    );
}

#[test]
fn the_same_track_with_a_length_that_jitters_by_a_fraction_of_a_second_is_the_same_track() {
    // Seen on a real client: 194.1 s when parked, 194.0 s once resumed.
    let parked = Snapshot {
        length: Duration::from_millis(194_100),
        ..snap("Song", 193, Playback::Paused)
    };
    let resumed = Snapshot {
        length: Duration::from_millis(194_000),
        ..snap("Song", 193, Playback::Playing)
    };
    assert_eq!(judge(&parked, &resumed), Verdict::Resumed);
}

#[test]
fn what_decides_is_where_the_track_plays_from_not_which_track_it_is() {
    let before = snap("Song", 100, Playback::Paused);
    let longer = |position| Snapshot {
        length: Duration::from_secs(LENGTH + 40),
        ..snap("Song", position, Playback::Playing)
    };
    assert_eq!(judge(&before, &longer(1)), Verdict::Started);
    assert_eq!(judge(&before, &longer(100)), Verdict::Resumed);
}

#[test]
fn a_different_track_that_plays_from_the_middle_is_repaired_back_to_track_1() {
    // Another album was playing; track 1 was asked for; Spotify went to track 4 of the album, 25 s in.
    let (mut s, log) = Spotify::on(7, 18, 0);
    s.playing = true;
    s.resume_to = Some((3, 25));
    let before = s.shot();
    let mut published = Vec::new();
    let result = start(
        &mut s,
        "spotify:track:x",
        &before,
        &mut |x| published.push(x.clone()),
        &|_| {},
    );
    assert_eq!(result, Ok(()));
    assert_eq!((s.current, s.position <= 3, s.playing), (0, true, true));
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn a_track_that_was_playing_and_is_replaced_by_a_real_start_needs_no_repair() {
    // Skipping from the middle of one track to a requested one that starts at its beginning.
    let (mut s, log) = Spotify::on(2, 100, 6);
    s.playing = true;
    let before = s.shot();
    let result = start(&mut s, "spotify:track:x", &before, &mut |_| {}, &|_| {});
    assert_eq!(result, Ok(()));
    assert_eq!(s.current, 6);
    assert!(
        !log.lock()
            .unwrap()
            .iter()
            .any(|l| l == "previous" || l.starts_with("volume"))
    );
}

#[test]
fn a_different_track_playing_from_the_middle_is_not_a_start() {
    // Spotify went to the album's last track and position instead of starting the one asked for.
    let before = snap("Other album", 18, Playback::Playing);
    assert_eq!(
        judge(&before, &snap("Track 4", 25, Playback::Playing)),
        Verdict::Resumed
    );
}

fn run_expecting(spotify: &mut Spotify, number: Option<u32>) -> Result<(), String> {
    let before = Snapshot {
        playback: Playback::Paused,
        ..spotify.shot()
    };
    spotify.playing = false;
    start_expecting(
        spotify,
        "spotify:track:x",
        number,
        &before,
        &mut |_| {},
        &|_| {},
    )
}

#[test]
fn spotify_playing_the_wrong_track_from_its_beginning_is_caught_by_the_number() {
    // The case that went wrong in a session: track 1 asked for, another album playing, Spotify went
    // to track 4 of the album and started it from 0:00. Nothing in the position gives it away.
    let (mut s, log) = Spotify::on(7, 18, 0);
    s.playing = true;
    s.resume_to = Some((3, 0));
    let before = s.shot();
    let result = start_expecting(
        &mut s,
        "spotify:track:x",
        Some(1),
        &before,
        &mut |_| {},
        &|_| {},
    );
    assert_eq!(result, Ok(()));
    assert_eq!((s.current, s.position <= 3, s.playing), (0, true, true));
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn a_track_that_is_ahead_of_the_one_asked_for_is_reached_by_skipping_forward() {
    // Track 6 asked for and Spotify is on track 4: two skips forward, never back to track 1.
    let (mut s, log) = Spotify::on(3, 0, 5);
    s.requested = 0; // Spotify ignores the request and stays on what it plays
    s.resume_to = Some((3, 0));
    s.playing = true;
    let before = s.shot();
    let result = start_expecting(
        &mut s,
        "spotify:track:x",
        Some(6),
        &before,
        &mut |_| {},
        &|_| {},
    );
    assert_eq!(result, Ok(()));
    assert_eq!(s.current, 5);
    let log = log.lock().unwrap();
    assert_eq!(log.iter().filter(|l| *l == "next").count(), 2, "{log:?}");
    assert!(!log.iter().any(|l| l == "previous"));
}

#[test]
fn the_right_track_from_its_beginning_is_left_alone() {
    let (mut s, log) = Spotify::on(2, 40, 6);
    assert_eq!(run_expecting(&mut s, Some(7)), Ok(()));
    assert_eq!(s.current, 6);
    let log = log.lock().unwrap();
    assert!(
        !log.iter()
            .any(|l| l == "previous" || l == "next" || l.starts_with("volume")),
        "{log:?}"
    );
}

#[test]
fn the_right_track_resumed_from_the_middle_is_restarted() {
    let (mut s, log) = Spotify::on(0, 40, 0);
    assert_eq!(run_expecting(&mut s, Some(1)), Ok(()));
    assert_eq!((s.current, s.position <= 3, s.playing), (0, true, true));
    assert!(log.lock().unwrap().iter().any(|l| l == "seek 0"));
    assert!(!log.lock().unwrap().iter().any(|l| l == "previous"));
}

#[test]
fn without_a_track_number_from_spotify_the_position_decides_as_before() {
    let (mut s, _) = Spotify::on(2, 40, 6);
    s.numbered = false;
    assert_eq!(run_expecting(&mut s, Some(7)), Ok(()));
    assert_eq!(s.current, 6);
}

#[test]
fn an_expected_number_that_cannot_be_reached_fails_the_command_and_restores_the_volume() {
    let (mut s, _) = Spotify::on(7, 18, 0);
    s.playing = true;
    s.resume_to = Some((3, 0));
    s.stuck = true;
    let before = s.shot();
    let result = start_expecting(
        &mut s,
        "spotify:track:x",
        Some(1),
        &before,
        &mut |_| {},
        &|_| {},
    );
    assert!(result.is_err());
    assert_eq!(s.volume, Some(0.8));
}

#[test]
fn run_answers_a_play_track_command_only_once_the_right_track_plays() {
    use crate::player::{Command, Reply, Request, run};
    use std::sync::mpsc::channel;

    let (mut spotify, log) = Spotify::on(7, 18, 0);
    spotify.playing = true;
    spotify.resume_to = Some((3, 0));
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let (request, reply) = Request::remote(
        Command::PlayTrack {
            uri: "spotify:track:x".into(),
            number: 1,
        },
        Duration::from_secs(30),
    );
    let handle = {
        let shared = shared.clone();
        std::thread::spawn(move || run(spotify, &rx, shared, Duration::from_millis(5)))
    };
    tx.send(request).unwrap();
    assert_eq!(reply.recv_timeout(Duration::from_secs(10)), Ok(Reply::Done));
    assert_eq!(shared.lock().unwrap().title, "Track 1");
    drop(tx);
    handle.join().unwrap();
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
}

fn playing_as(title: &str, number: u32, length_s: u64, position: u64) -> Snapshot {
    Snapshot {
        running: true,
        title: title.into(),
        artist: "A".into(),
        track_number: Some(number),
        length: Duration::from_secs(length_s),
        position: Duration::from_secs(position),
        playback: Playback::Playing,
        ..Snapshot::default()
    }
}

/// A Spotify whose properties arrive one after the other while it switches: for a moment the old
/// title and track number come with the new track's length. Navigation then works as in `Spotify`.
struct Settling {
    inner: Spotify,
    /// Snapshots to show first, in the order they are taken after the command.
    transition: Vec<Snapshot>,
    shown: usize,
    launched: bool,
}

impl Backend for Settling {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        if self.launched && self.shown < self.transition.len() {
            let s = self.transition[self.shown].clone();
            self.shown += 1;
            return Ok(s);
        }
        self.inner.snapshot()
    }
    fn toggle_play_pause(&mut self) -> Result<(), String> {
        self.inner.toggle_play_pause()
    }
    fn pause(&mut self) -> Result<(), String> {
        self.inner.pause()
    }
    fn play(&mut self) -> Result<(), String> {
        self.inner.play()
    }
    fn seek(&mut self, to: Duration) -> Result<(), String> {
        self.inner.seek(to)
    }
    fn next(&mut self) -> Result<(), String> {
        self.inner.next()
    }
    fn previous(&mut self) -> Result<(), String> {
        self.inner.previous()
    }
    fn set_volume(&mut self, v: f32) -> Result<(), String> {
        self.inner.set_volume(v)
    }
    fn play_uri(&mut self, uri: &str) -> Result<(), String> {
        self.launched = true;
        self.inner.play_uri(uri)
    }
    fn verifies_start(&self) -> bool {
        true
    }
}

#[test]
fn a_half_updated_snapshot_is_not_judged_the_settled_one_is() {
    // The live failure: track 1 asked for. Spotify shows "Speak To Me, track 1" with track 4's
    // length for a while, then settles on track 4. Judging the first would call it a start.
    let (mut inner, log) = Spotify::on(3, 0, 0);
    inner.playing = true; // after the transition: track 4 at its start, playing
    let transition: Vec<Snapshot> = (0..6)
        .map(|i| playing_as("Track 1", 1, LENGTH, i % 2))
        .collect();
    let before = playing_as("Track 1", 1, 64, 20);
    let mut spotify = Settling {
        inner,
        transition,
        shown: 0,
        launched: false,
    };
    let result = start_expecting(
        &mut spotify,
        "spotify:track:x",
        Some(1),
        &before,
        &mut |_| {},
        &|_| {},
    );
    assert_eq!(result, Ok(()));
    // It ended on track 1 by walking back from where Spotify really was (track 4).
    assert_eq!(spotify.inner.current, 0);
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "previous")
            .count(),
        3
    );
}

#[test]
fn a_snapshot_has_to_hold_for_about_a_second_before_it_counts() {
    assert!(STABLE_POLLS as u64 * STEP.as_millis() as u64 >= 800);
}
