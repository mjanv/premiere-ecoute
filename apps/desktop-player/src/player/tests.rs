use super::*;

fn playing() -> Snapshot {
    Snapshot {
        running: true,
        title: "Song".into(),
        playback: Playback::Playing,
        ..Snapshot::default()
    }
}

#[test]
fn album_line_hides_albums_that_only_repeat_the_title() {
    let with = |title: &str, album: &str| Snapshot {
        title: title.into(),
        album: album.into(),
        ..playing()
    };
    assert_eq!(with("Black Swan", "Black Swan").album_line(), None);
    assert_eq!(with("Black Swan", "  black swan ").album_line(), None);
    assert_eq!(with("Black Swan", "Black Swan - Single").album_line(), None);
    assert_eq!(with("Black Swan", "Black Swan - EP").album_line(), None);
    assert_eq!(with("Black Swan", "").album_line(), None);
    assert_eq!(
        with("Black Swan", "Black Swan (Deluxe)").album_line(),
        Some("Black Swan (Deluxe)")
    );
    assert_eq!(
        with("From", "SABLE, fABLE").album_line(),
        Some("SABLE, fABLE")
    );
}

#[test]
fn state_label_is_one_short_word_for_the_eyebrow() {
    assert_eq!(playing().state_label(), "Playing");
    assert_eq!(
        Snapshot {
            playback: Playback::Paused,
            ..playing()
        }
        .state_label(),
        "Paused"
    );
    assert_eq!(
        Snapshot {
            playback: Playback::Stopped,
            ..playing()
        }
        .state_label(),
        "Stopped"
    );
    assert_eq!(Snapshot::not_running().state_label(), "Not running");
    assert_eq!(Snapshot::failed("x").state_label(), "Unavailable");
}

#[test]
fn cannot_control_when_not_running_or_failed() {
    assert!(playing().can_control());
    assert!(!Snapshot::not_running().can_control());
    assert!(!Snapshot::failed("x").can_control());
}

#[test]
fn current_position_advances_only_while_playing_and_stays_in_range() {
    let s = Duration::from_secs;
    assert_eq!(
        current_position(s(10), s(3), Playback::Playing, s(100)),
        s(13)
    );
    assert_eq!(
        current_position(s(10), s(3), Playback::Paused, s(100)),
        s(10)
    );
    assert_eq!(
        current_position(s(98), s(5), Playback::Playing, s(100)),
        s(100)
    );
}

#[test]
fn progress_is_a_fraction_and_zero_without_length() {
    let s = Snapshot {
        position: Duration::from_secs(30),
        length: Duration::from_secs(120),
        ..playing()
    };
    assert_eq!(s.progress(), 0.25);
    assert_eq!(playing().progress(), 0.0);
}

#[test]
fn format_time_is_minutes_and_zero_padded_seconds() {
    assert_eq!(format_time(Duration::from_secs(0)), "0:00");
    assert_eq!(format_time(Duration::from_secs(65)), "1:05");
    assert_eq!(format_time(Duration::from_secs(3725)), "62:05");
}

const ID: &str = "4cOdK2wGLETKBW3PvgPWqT";

#[test]
fn parse_track_uri_accepts_uris_and_links() {
    let want = Ok(format!("spotify:track:{ID}"));
    assert_eq!(parse_track_uri(&format!("spotify:track:{ID}")), want);
    assert_eq!(
        parse_track_uri(&format!(" https://open.spotify.com/track/{ID}?si=abc ")),
        want
    );
    assert_eq!(
        parse_track_uri(&format!("open.spotify.com/intl-fr/track/{ID}")),
        want
    );
}

#[test]
fn autoplay_uri_makes_the_desktop_app_start_the_track() {
    assert_eq!(
        autoplay_uri("spotify:track:abc"),
        "spotify:track:abc?autoplay=true"
    );
}

#[test]
fn parse_track_uri_rejects_other_input() {
    assert!(parse_track_uri("").is_err());
    assert!(parse_track_uri("spotify:album:4cOdK2wGLETKBW3PvgPWqT").is_err());
    assert!(parse_track_uri("spotify:track:short").is_err());
    assert!(parse_track_uri("spotify:track:4cOdK2wGLETKBW3PvgPWq&").is_err());
}

#[derive(Default)]
struct Fake {
    playing: bool,
    fail_next: bool,
    log: Arc<Mutex<Vec<String>>>,
}

impl Backend for Fake {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        let playback = if self.playing {
            Playback::Playing
        } else {
            Playback::Paused
        };
        Ok(Snapshot {
            playback,
            ..playing()
        })
    }

    fn toggle_play_pause(&mut self) -> Result<(), String> {
        self.playing = !self.playing;
        Ok(())
    }

    fn next(&mut self) -> Result<(), String> {
        if self.fail_next {
            return Err("boom".into());
        }
        self.log.lock().unwrap().push("next".into());
        Ok(())
    }

    fn previous(&mut self) -> Result<(), String> {
        self.log.lock().unwrap().push("previous".into());
        Ok(())
    }

    fn set_volume(&mut self, volume: f32) -> Result<(), String> {
        self.log.lock().unwrap().push(format!("volume {volume}"));
        Ok(())
    }

    fn play_uri(&mut self, uri: &str) -> Result<(), String> {
        self.log.lock().unwrap().push(format!("play {uri}"));
        Ok(())
    }
}

#[test]
fn failed_command_leaves_a_notice_without_disabling_controls() {
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let backend = Fake {
        fail_next: true,
        ..Fake::default()
    };
    let handle = {
        let shared = shared.clone();
        std::thread::spawn(move || run(backend, &rx, shared, Duration::from_millis(5)))
    };

    tx.send(Request::local(Command::Next)).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while shared.lock().unwrap().notice.is_none() {
        assert!(
            std::time::Instant::now() < deadline,
            "no notice was published"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    // Several polls later the notice must still be there, and the player still usable.
    std::thread::sleep(Duration::from_millis(50));
    let snap = shared.lock().unwrap().clone();
    assert_eq!(snap.notice.as_deref(), Some("boom"));
    assert!(snap.can_control());

    drop(tx);
    handle.join().unwrap();
}

fn spawn_run(
    backend: Fake,
) -> (
    Sender<Request>,
    Arc<Mutex<Snapshot>>,
    std::thread::JoinHandle<()>,
) {
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let handle = {
        let shared = shared.clone();
        std::thread::spawn(move || run(backend, &rx, shared, Duration::from_millis(5)))
    };
    (tx, shared, handle)
}

#[test]
fn a_remote_request_is_answered_and_does_not_become_a_notice() {
    let (tx, shared, handle) = spawn_run(Fake {
        fail_next: true,
        ..Fake::default()
    });

    let (ok, ok_reply) = Request::remote(Command::Previous, Duration::from_secs(5));
    tx.send(ok).unwrap();
    assert_eq!(
        ok_reply.recv_timeout(Duration::from_secs(2)),
        Ok(Reply::Done)
    );

    let (bad, bad_reply) = Request::remote(Command::Next, Duration::from_secs(5));
    tx.send(bad).unwrap();
    assert_eq!(
        bad_reply.recv_timeout(Duration::from_secs(2)),
        Ok(Reply::Failed("boom".into()))
    );
    std::thread::sleep(Duration::from_millis(30));
    assert_eq!(lock(&shared).notice, None);

    drop(tx);
    handle.join().unwrap();
}

#[test]
fn a_request_past_its_deadline_is_not_run() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let (tx, _shared, handle) = spawn_run(Fake {
        log: log.clone(),
        ..Fake::default()
    });

    let (late, reply) = Request::remote(Command::Next, Duration::ZERO);
    tx.send(late).unwrap();
    assert_eq!(
        reply.recv_timeout(Duration::from_secs(2)),
        Ok(Reply::Expired)
    );

    drop(tx);
    handle.join().unwrap();
    assert!(log.lock().unwrap().is_empty());
}

#[test]
fn lock_recovers_from_a_poisoned_mutex() {
    let m = Arc::new(Mutex::new(1));
    let poisoner = m.clone();
    let _ = std::thread::spawn(move || {
        let _guard = poisoner.lock().unwrap();
        panic!("poison it");
    })
    .join();
    assert!(m.is_poisoned());
    assert_eq!(*lock(&m), 1);
}

#[test]
fn run_forwards_next_previous_and_volume() {
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let log = Arc::new(Mutex::new(Vec::new()));
    let (tx, rx) = channel();
    let backend = Fake {
        log: log.clone(),
        ..Fake::default()
    };
    let handle = std::thread::spawn(move || run(backend, &rx, shared, Duration::from_millis(5)));

    tx.send(Request::local(Command::Next)).unwrap();
    tx.send(Request::local(Command::Previous)).unwrap();
    tx.send(Request::local(Command::SetVolume(0.5))).unwrap();
    tx.send(Request::local(Command::PlayUri("spotify:track:x".into())))
        .unwrap();
    drop(tx);
    handle.join().unwrap();

    assert_eq!(
        *log.lock().unwrap(),
        ["next", "previous", "volume 0.5", "play spotify:track:x"]
    );
}

#[test]
fn run_publishes_state_and_applies_commands() {
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let handle = {
        let shared = shared.clone();
        std::thread::spawn(move || {
            run(
                Fake {
                    playing: true,
                    ..Fake::default()
                },
                &rx,
                shared,
                Duration::from_millis(5),
            )
        })
    };

    tx.send(Request::local(Command::TogglePlayPause)).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while shared.lock().unwrap().playback != Playback::Paused {
        assert!(
            std::time::Instant::now() < deadline,
            "state never became Paused"
        );
        std::thread::sleep(Duration::from_millis(5));
    }

    drop(tx);
    handle.join().unwrap();
}

fn track(title: &str, position: u64, length: u64) -> Snapshot {
    Snapshot {
        title: title.into(),
        artist: "Artist".into(),
        position: Duration::from_secs(position),
        length: Duration::from_secs(length),
        ..playing()
    }
}

fn armed(before: &Snapshot, t0: Instant) -> StopAtEnd {
    let mut guard = StopAtEnd::default();
    guard.arm(before, t0);
    guard
}

#[test]
fn a_commanded_track_is_paused_in_its_last_second() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Old", 100, 200), t0);
    assert!(!guard.observe(&track("New", 1, 180), t0));
    assert!(!guard.observe(&track("New", 150, 180), t0));
    assert!(!guard.observe(&track("New", 178, 180), t0));
    assert!(guard.observe(&track("New", 179, 180), t0));
    // Once paused it does nothing more, even if the user resumes into the next song.
    assert!(!guard.observe(&track("New", 179, 180), t0));
}

#[test]
fn the_guard_follows_only_the_commanded_track() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Old", 100, 200), t0);
    assert!(!guard.observe(&track("New", 1, 180), t0));
    // The user skipped to another song: leave it alone.
    assert!(!guard.observe(&track("Other", 179, 180), t0));
    assert!(!guard.observe(&track("Other", 179, 180), t0));
}

#[test]
fn the_old_track_is_never_paused_while_waiting_for_the_new_one() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Old", 199, 200), t0);
    assert!(!guard.observe(&track("Old", 199, 200), t0));
    assert!(!guard.observe(&track("New", 1, 180), t0));
}

#[test]
fn the_same_track_played_again_is_guarded_after_it_restarts() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Song", 170, 180), t0);
    assert!(!guard.observe(&track("Song", 175, 180), t0));
    assert!(!guard.observe(&track("Song", 2, 180), t0));
    assert!(guard.observe(&track("Song", 179, 180), t0));
}

#[test]
fn a_command_that_never_starts_a_track_expires() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Old", 100, 200), t0);
    let late = t0 + Duration::from_secs(30);
    assert!(!guard.observe(&track("Old", 100, 200), late));
    assert!(!guard.observe(&track("New", 179, 180), late));
}

#[test]
fn a_paused_or_unguarded_player_is_left_alone() {
    let t0 = Instant::now();
    assert!(!StopAtEnd::default().observe(&track("Song", 179, 180), t0));
    let mut guard = armed(&track("Old", 100, 200), t0);
    assert!(!guard.observe(&track("New", 1, 180), t0));
    let paused = Snapshot {
        playback: Playback::Paused,
        ..track("New", 179, 180)
    };
    assert!(!guard.observe(&paused, t0));
}

#[test]
fn the_guard_asks_to_wake_at_the_last_second() {
    let t0 = Instant::now();
    let mut guard = armed(&track("Old", 100, 200), t0);
    assert_eq!(guard.wake_in(), None);
    guard.observe(&track("New", 170, 180), t0);
    assert_eq!(guard.wake_in(), Some(Duration::from_secs(9)));
}

#[test]
fn run_pauses_a_commanded_track_in_its_last_second() {
    struct Ending {
        log: Arc<Mutex<Vec<String>>>,
        position: u64,
        started: bool,
    }
    impl Backend for Ending {
        fn snapshot(&mut self) -> Result<Snapshot, String> {
            Ok(if self.started {
                track("New", self.position, 180)
            } else {
                track("Old", 50, 100)
            })
        }
        fn toggle_play_pause(&mut self) -> Result<(), String> {
            self.log.lock().unwrap().push("toggle".into());
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
            self.started = true;
            self.position = 179; // already in the last second at the next poll
            Ok(())
        }
    }
    let log = Arc::new(Mutex::new(Vec::new()));
    let backend = Ending {
        log: log.clone(),
        position: 0,
        started: false,
    };
    let shared = Arc::new(Mutex::new(Snapshot::default()));
    let (tx, rx) = channel();
    let handle = std::thread::spawn(move || run(backend, &rx, shared, Duration::from_millis(5)));
    tx.send(Request::local(Command::PlayUri("spotify:track:x".into())))
        .unwrap();
    let deadline = Instant::now() + Duration::from_secs(2);
    while !log.lock().unwrap().contains(&"toggle".to_string()) {
        assert!(Instant::now() < deadline, "the track was not paused");
        std::thread::sleep(Duration::from_millis(5));
    }
    drop(tx);
    handle.join().unwrap();
    assert_eq!(
        log.lock()
            .unwrap()
            .iter()
            .filter(|l| *l == "toggle")
            .count(),
        1
    );
}
