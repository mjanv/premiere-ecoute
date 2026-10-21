use crate::artwork::Artwork;
use crate::ending::Ending;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::{Duration, Instant};

/// Locks shared state, recovering from poisoning: the data is a plain value that is always valid,
/// and one panicked thread must not take every other thread down with it.
pub fn lock<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(PoisonError::into_inner)
}

/// How long a failed command's message stays visible.
const NOTICE_HOLD: Duration = Duration::from_secs(4);

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Playback {
    Playing,
    Paused,
    #[default]
    Stopped,
}

/// Spotify's repeat mode, as SMTC reports it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Repeat {
    None,
    Track,
    List,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Snapshot {
    pub running: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_artist: String,
    /// Position of the track in its album; `None` when Spotify does not say.
    pub track_number: Option<u32>,
    pub album_track_count: Option<u32>,
    pub genres: Vec<String>,
    /// `None` when SMTC does not report the mode.
    pub shuffle: Option<bool>,
    pub repeat: Option<Repeat>,
    pub playback: Playback,
    pub position: Duration,
    pub length: Duration,
    pub artwork: Option<Artwork>,
    /// Identity of the current track, sent to the backend, which detects track changes by comparing it.
    pub uri: Option<String>,
    /// Spotify's own volume (0.0..=1.0), when it has an audio session.
    pub volume: Option<f32>,
    /// Backend unavailable: the whole player is unusable.
    pub error: Option<String>,
    /// The last command failed; shown briefly, the player stays usable.
    pub notice: Option<String>,
}

impl Snapshot {
    pub fn not_running() -> Self {
        Self::default()
    }

    pub fn failed(error: impl ToString) -> Self {
        Self {
            error: Some(error.to_string()),
            ..Self::default()
        }
    }

    /// The album to show next to the artist: nothing when it only repeats the title
    /// (singles are released as an album named after the track).
    pub fn album_line(&self) -> Option<&str> {
        let album = self.album.trim();
        let norm = |s: &str| {
            let s = s.trim().to_lowercase();
            s.strip_suffix(" - single")
                .or_else(|| s.strip_suffix(" - ep"))
                .map(str::to_string)
                .unwrap_or(s)
        };
        (!album.is_empty() && norm(album) != norm(&self.title)).then_some(album)
    }

    /// One word describing Spotify's state.
    pub fn state_label(&self) -> &'static str {
        if self.error.is_some() {
            return "Unavailable";
        }
        if !self.running {
            return "Not running";
        }
        match self.playback {
            Playback::Playing => "Playing",
            Playback::Paused => "Paused",
            Playback::Stopped => "Stopped",
        }
    }

    /// Fraction played, 0.0..=1.0.
    pub fn progress(&self) -> f32 {
        if self.length.is_zero() {
            return 0.0;
        }
        (self.position.as_secs_f32() / self.length.as_secs_f32()).clamp(0.0, 1.0)
    }

    pub fn can_control(&self) -> bool {
        self.running && self.error.is_none()
    }
}

/// SMTC only reports the position at the last update; add the time elapsed since.
pub fn current_position(
    reported: Duration,
    since_update: Duration,
    playback: Playback,
    length: Duration,
) -> Duration {
    match playback {
        Playback::Playing => (reported + since_update).min(length),
        _ => reported,
    }
}

pub fn format_time(t: Duration) -> String {
    let secs = t.as_secs();
    format!("{}:{:02}", secs / 60, secs % 60)
}

/// Normalizes a Spotify track URI or open.spotify.com link to `spotify:track:<id>`.
/// Used to validate `play_uri` commands that come from the backend (ADR 0001).
#[allow(dead_code)]
pub fn parse_track_uri(input: &str) -> Result<String, String> {
    let input = input.trim();
    let id = if let Some(id) = input.strip_prefix("spotify:track:") {
        id
    } else if let Some((_, rest)) = input.split_once("open.spotify.com/") {
        let path = rest.split(['?', '#']).next().unwrap_or("");
        path.rsplit_once("track/").map(|(_, id)| id).unwrap_or("")
    } else {
        ""
    };
    if id.len() == 22 && id.chars().all(|c| c.is_ascii_alphanumeric()) {
        Ok(format!("spotify:track:{id}"))
    } else {
        Err("expected a Spotify track URI or link".into())
    }
}

/// A plain `spotify:track:` URI only opens the album page in the desktop app; this makes it play.
pub fn autoplay_uri(uri: &str) -> String {
    format!("{uri}?autoplay=true")
}

/// How long before the end a commanded track is paused.
const END_MARGIN: Duration = Duration::from_secs(1);
/// How long a `play_uri` waits for its track to show up in the snapshots.
const ARM_TTL: Duration = Duration::from_secs(20);
/// A followed identity that changes within this long of the lock, to a track near its start, was
/// still settling and is not a skip.
const RELOCK: Duration = Duration::from_secs(5);
const RELOCK_POSITION: Duration = Duration::from_secs(5);
/// How long the current track is left alone after a command before it is taken for the commanded
/// one: the new track may take a moment to start (the app is launched through the URL handler).
const SETTLE: Duration = Duration::from_secs(4);
/// A followed track replaced when this close to its end went by unseen, it was not skipped.
const LATE: Duration = Duration::from_secs(3);

/// The desktop app plays a commanded track inside its album and carries on with the next song
/// (no URI variant avoids that, see docs/architecture.md). Pauses the track in its last second so
/// a `play_uri` plays that one track only.
#[derive(Default)]
pub struct StopAtEnd {
    state: Guard,
    /// The followed track was replaced just after its end, before the pause: see `take_missed`.
    missed: bool,
}

#[derive(Default)]
enum Guard {
    #[default]
    Idle,
    /// A `play_uri` was accepted; waiting for its track to start.
    Armed {
        before: (String, String, Duration),
        position: Duration,
        /// Whether it was playing: if not, any playing afterwards is the command taking effect.
        was_playing: bool,
        since: Instant,
    },
    /// Following the commanded track.
    Following {
        track: (String, String, Duration),
        remaining: Duration,
        /// When it locked on: an identity that changes right after was a transitional one.
        since: Instant,
    },
}

/// What identifies a track in the snapshots: title, artist and length.
pub type Identity = (String, String, Duration);

fn track_key(s: &Snapshot) -> Identity {
    (s.title.clone(), s.artist.clone(), s.length)
}

/// How much the length of one track may differ between two readings. Seen on a real client:
/// 194.1 s when parked, 194.0 s once resumed. A different track of the same title and artist
/// differing by less than this is not worth telling apart.
const LENGTH_JITTER: Duration = Duration::from_millis(1500);

/// Whether two identities are the same track, allowing for the jitter of the length.
pub fn same_track(a: &Identity, b: &Identity) -> bool {
    a.0 == b.0 && a.1 == b.1 && a.2.abs_diff(b.2) <= LENGTH_JITTER
}

impl StopAtEnd {
    /// Call after a `play_uri` was accepted; `before` is the last snapshot taken before it.
    pub fn arm(&mut self, before: &Snapshot, now: Instant) {
        self.state = Guard::Armed {
            before: track_key(before),
            position: before.position,
            was_playing: before.playback == Playback::Playing,
            since: now,
        };
    }

    /// Returns true when playback must be paused now.
    pub fn observe(&mut self, snap: &Snapshot, now: Instant) -> bool {
        let key = track_key(snap);
        let playing = snap.playback == Playback::Playing && !snap.length.is_zero();
        match &self.state {
            Guard::Idle => false,
            Guard::Armed {
                before,
                position,
                was_playing,
                since,
            } => {
                let waited = now.saturating_duration_since(*since);
                if waited > ARM_TTL {
                    self.state = Guard::Idle;
                    return false;
                }
                // A new track, or the same one restarted from near the start. The desktop app does
                // not always switch: it may resume what was loaded (paused before, or still
                // playing after a few seconds). Whatever plays is then the commanded track.
                let started = playing
                    && (!same_track(&key, before)
                        || snap.position + Duration::from_secs(2) < *position
                        || !*was_playing
                        || waited >= SETTLE);
                if started {
                    self.state = Guard::Following {
                        track: key,
                        remaining: Duration::MAX,
                        since: now,
                    };
                    return self.observe(snap, now);
                }
                false
            }
            Guard::Following {
                track,
                remaining,
                since,
            } => {
                if !same_track(&key, track) {
                    // Spotify updates the title and the length one after the other: right after
                    // the lock the identity may still be settling, with the new track near its
                    // start. That is the same track, not a skip: follow the settled identity.
                    // Not when the followed track was close to its end: that one really ended.
                    let settling = playing
                        && now.saturating_duration_since(*since) < RELOCK
                        && snap.position <= RELOCK_POSITION
                        && *remaining > LATE;
                    if settling {
                        self.state = Guard::Following {
                            track: key,
                            remaining: Duration::MAX,
                            since: *since,
                        };
                        return self.observe(snap, now);
                    }
                    // Close to its end when last seen: Spotify moved on before the pause.
                    self.missed = *remaining != Duration::MAX && *remaining <= LATE;
                    self.state = Guard::Idle;
                    return false;
                }
                let remaining = snap.length.saturating_sub(snap.position);
                if playing && remaining <= END_MARGIN {
                    self.state = Guard::Idle;
                    return true;
                }
                self.state = Guard::Following {
                    track: key,
                    remaining: if playing { remaining } else { Duration::MAX },
                    since: *since,
                };
                false
            }
        }
    }

    /// True once after the followed track was replaced just after its end: the next track plays
    /// and has to be paused now.
    pub fn take_missed(&mut self) -> bool {
        std::mem::take(&mut self.missed)
    }

    /// The guard's state by name, for the log.
    pub fn describe(&self) -> &'static str {
        match &self.state {
            Guard::Idle => "idle",
            Guard::Armed { .. } => "waiting for the commanded track",
            Guard::Following { .. } => "following the commanded track",
        }
    }

    /// Whether `snap` is the track being followed.
    pub fn guarded(&self, snap: &Snapshot) -> bool {
        matches!(&self.state, Guard::Following { track, .. } if same_track(track, &track_key(snap)))
    }

    /// Starts following the track that plays, without a command: while a listening session runs,
    /// whatever plays is stopped at its end, whoever started it (the player may have restarted, or
    /// the streamer may have pressed play in Spotify). Does nothing when the guard is already
    /// busy, or when the track is not playing, has no length, or is already in its last second.
    pub fn follow(&mut self, snap: &Snapshot, now: Instant) -> bool {
        let playing = snap.playback == Playback::Playing && !snap.length.is_zero();
        let remaining = snap.length.saturating_sub(snap.position);
        if !matches!(self.state, Guard::Idle) || !playing || remaining <= END_MARGIN {
            return false;
        }
        self.state = Guard::Following {
            track: track_key(snap),
            remaining,
            since: now,
        };
        true
    }

    /// How long until the track enters its last second, so the loop can wake up in time.
    pub fn wake_in(&self) -> Option<Duration> {
        match &self.state {
            Guard::Following { remaining, .. } if *remaining != Duration::MAX => {
                Some(remaining.saturating_sub(END_MARGIN))
            }
            _ => None,
        }
    }
}

pub trait Backend {
    fn snapshot(&mut self) -> Result<Snapshot, String>;
    fn toggle_play_pause(&mut self) -> Result<(), String>;
    /// Pauses, and never resumes. The default is the toggle, for a backend with nothing better.
    fn pause(&mut self) -> Result<(), String> {
        self.toggle_play_pause()
    }
    /// Whether this backend can read, pause, seek and skip well enough for `start::start` to check
    /// that a commanded track really started, and repair it when it did not.
    fn verifies_start(&self) -> bool {
        false
    }
    /// Turns shuffle on or off. Not every backend can.
    fn set_shuffle(&mut self, _on: bool) -> Result<(), String> {
        Err("shuffle is not supported".into())
    }
    /// Sets the repeat mode. Not every backend can.
    fn set_repeat(&mut self, _repeat: Repeat) -> Result<(), String> {
        Err("repeat is not supported".into())
    }
    /// Starts or resumes playback. Not every backend can.
    fn play(&mut self) -> Result<(), String> {
        Err("play is not supported".into())
    }
    /// Moves to `to` in the current track. Not every backend can.
    fn seek(&mut self, _to: Duration) -> Result<(), String> {
        Err("seek is not supported".into())
    }
    /// Whether `pause` on a paused player does nothing. Only then can it be repeated safely: a
    /// toggle would resume.
    fn pause_is_idempotent(&self) -> bool {
        false
    }
    fn next(&mut self) -> Result<(), String>;
    fn previous(&mut self) -> Result<(), String>;
    fn set_volume(&mut self, volume: f32) -> Result<(), String>;
    /// `uri` is a validated `spotify:track:<id>`.
    fn play_uri(&mut self, uri: &str) -> Result<(), String>;
}

/// `PlayUri` is sent by the backend (ADR 0001); the window no longer offers a track field.
#[allow(dead_code)]
#[derive(Clone, Debug, PartialEq)]
pub enum Command {
    TogglePlayPause,
    Next,
    Previous,
    SetVolume(f32),
    PlayUri(String),
    /// `PlayUri` for an album track whose position in its album is known: the player checks that
    /// this is the track that plays, and goes to it if not.
    PlayTrack {
        uri: String,
        number: u32,
    },
}

/// What happened to a command that asked for a reply.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Reply {
    Done,
    Failed(String),
    /// Its deadline passed before it started: it was not run.
    Expired,
}

/// A command plus how to answer it. Local (UI) requests have no reply: failures become a notice.
/// Remote requests carry a deadline and a reply channel, which becomes the ack to the backend.
pub struct Request {
    pub command: Command,
    pub reply: Option<Sender<Reply>>,
    pub deadline: Option<Instant>,
}

impl Request {
    pub fn local(command: Command) -> Self {
        Self {
            command,
            reply: None,
            deadline: None,
        }
    }

    pub fn remote(command: Command, ttl: Duration) -> (Self, Receiver<Reply>) {
        let (tx, rx) = std::sync::mpsc::channel();
        (
            Self {
                command,
                reply: Some(tx),
                deadline: Some(Instant::now() + ttl),
            },
            rx,
        )
    }
}

/// Starts a commanded track and arms the guard that stops it at its end. A backend that can check
/// what plays does, and repairs what Spotify did not start as asked (`start.rs`).
fn play(
    backend: &mut impl Backend,
    guard: &mut StopAtEnd,
    ending: &mut Ending,
    shared: &Mutex<Snapshot>,
    uri: &str,
    number: Option<u32>,
) -> Result<(), String> {
    let before = lock(shared).clone();
    // A new track: the end of the previous one is over.
    ending.clear();
    let started = if backend.verifies_start() {
        let result = crate::start::start_expecting(
            backend,
            uri,
            number,
            &before,
            &mut |s| *lock(shared) = s.clone(),
            &std::thread::sleep,
        );
        if let Err(message) = &result {
            crate::log::warn(format!("play_uri {uri} failed: {message}"));
            // Never leave a track nobody asked for playing.
            let _ = backend.pause();
        }
        result
    } else {
        backend.play_uri(uri)
    };
    if started.is_ok() {
        guard.arm(&before, Instant::now());
        crate::log::info(format!("play_uri {uri}: guard armed"));
    }
    started
}

/// Whether the backend says a listening session is running. Written by the remote link, read by
/// the player loop started with `run_with`.
static SESSION_RUNNING: AtomicBool = AtomicBool::new(false);

pub fn session_running() -> &'static AtomicBool {
    &SESSION_RUNNING
}

/// Polls the backend and applies requests until the sender side is dropped, without ever stopping
/// tracks on its own initiative (the tests that do not care about sessions use it).
/// Takes the receiver by reference so a supervisor can restart it after a panic.
#[cfg(test)]
pub fn run(
    backend: impl Backend,
    commands: &Receiver<Request>,
    shared: Arc<Mutex<Snapshot>>,
    poll: Duration,
) {
    static NEVER: AtomicBool = AtomicBool::new(false);
    run_with(backend, commands, shared, poll, &NEVER);
}

/// Polls the backend and applies requests until the sender side is dropped, stopping whatever
/// plays at its end for as long as `session` is true.
/// Takes the receiver by reference so a supervisor can restart it after a panic.
pub fn run_with(
    mut backend: impl Backend,
    commands: &Receiver<Request>,
    shared: Arc<Mutex<Snapshot>>,
    poll: Duration,
    session: &'static AtomicBool,
) {
    let mut notice: Option<(String, Instant)> = None;
    let mut guard = StopAtEnd::default();
    let mut ending = Ending::default();
    loop {
        let mut snapshot = backend.snapshot().unwrap_or_else(Snapshot::failed);
        let now = Instant::now();
        if guard.guarded(&snapshot) {
            ending.remember(&snapshot);
        }
        let state_before = guard.describe();
        if session.load(Ordering::Relaxed) && guard.follow(&snapshot, now) {
            crate::log::info(format!(
                "session running: following {:?} to stop it at its end",
                snapshot.title
            ));
        }
        let reached = guard.observe(&snapshot, now);
        let missed = guard.take_missed();
        if guard.describe() != state_before {
            crate::log::info(format!(
                "guard: {state_before} -> {} ({:?}, {}/{} s, {:?})",
                guard.describe(),
                snapshot.title,
                snapshot.position.as_secs(),
                snapshot.length.as_secs(),
                snapshot.playback
            ));
        }
        // At the end of the commanded track, or just after it when Spotify was already on the next.
        if reached || missed {
            crate::log::info(format!(
                "commanded track {:?} ended ({}): pausing",
                snapshot.title,
                if reached {
                    "reached"
                } else {
                    "missed, Spotify already on the next track"
                }
            ));
            if let Err(message) = backend.pause() {
                crate::log::warn(format!("pause failed: {message}"));
                notice = Some((message, now));
            }
            ending.begin(now);
        }
        // What everyone else sees is the track ending, never the next one starting.
        if ending.apply(&mut snapshot, now, backend.pause_is_idempotent()) {
            crate::log::warn("Spotify played on after the pause: pausing again");
            if let Err(message) = backend.pause() {
                crate::log::warn(format!("pause failed: {message}"));
                notice = Some((message, now));
            }
        }
        notice = notice.filter(|(_, since)| since.elapsed() < NOTICE_HOLD);
        snapshot.notice = notice.as_ref().map(|(message, _)| message.clone());
        *lock(&shared) = snapshot;

        let wait = [guard.wake_in(), ending.wake_in(Instant::now())]
            .into_iter()
            .flatten()
            .fold(poll, Duration::min);
        match commands.recv_timeout(wait) {
            Ok(request) => {
                if request.deadline.is_some_and(|d| Instant::now() >= d) {
                    if let Some(reply) = request.reply {
                        let _ = reply.send(Reply::Expired);
                    }
                    continue;
                }
                let result = match request.command {
                    Command::TogglePlayPause => backend.toggle_play_pause(),
                    Command::Next => backend.next(),
                    Command::Previous => backend.previous(),
                    Command::SetVolume(v) => backend.set_volume(v),
                    Command::PlayUri(uri) => {
                        play(&mut backend, &mut guard, &mut ending, &shared, &uri, None)
                    }
                    Command::PlayTrack { uri, number } => play(
                        &mut backend,
                        &mut guard,
                        &mut ending,
                        &shared,
                        &uri,
                        Some(number),
                    ),
                };
                match request.reply {
                    Some(reply) => {
                        let _ = reply.send(match result {
                            Ok(()) => Reply::Done,
                            Err(message) => Reply::Failed(message),
                        });
                    }
                    None => {
                        if let Err(message) = result {
                            notice = Some((message, Instant::now()));
                        }
                    }
                }
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => return,
        }
    }
}

pub fn channel() -> (Sender<Request>, Receiver<Request>) {
    std::sync::mpsc::channel()
}

#[cfg(test)]
mod tests;
