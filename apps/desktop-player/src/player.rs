use crate::artwork::Artwork;
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

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Snapshot {
    pub running: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
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

/// The desktop app plays a commanded track inside its album and carries on with the next song
/// (no URI variant avoids that, see docs/architecture.md). Pauses the track in its last second so
/// a `play_uri` plays that one track only.
#[derive(Default)]
pub struct StopAtEnd {
    state: Guard,
}

#[derive(Default)]
enum Guard {
    #[default]
    Idle,
    /// A `play_uri` was accepted; waiting for its track to start.
    Armed {
        before: (String, String, Duration),
        position: Duration,
        since: Instant,
    },
    /// Following the commanded track.
    Following {
        track: (String, String, Duration),
        remaining: Duration,
    },
}

fn track_key(s: &Snapshot) -> (String, String, Duration) {
    (s.title.clone(), s.artist.clone(), s.length)
}

impl StopAtEnd {
    /// Call after a `play_uri` was accepted; `before` is the last snapshot taken before it.
    pub fn arm(&mut self, before: &Snapshot, now: Instant) {
        self.state = Guard::Armed {
            before: track_key(before),
            position: before.position,
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
                since,
            } => {
                if now.saturating_duration_since(*since) > ARM_TTL {
                    self.state = Guard::Idle;
                    return false;
                }
                // A new track, or the same one restarted from near the start.
                let started = playing
                    && (key != *before || snap.position + Duration::from_secs(2) < *position);
                if started {
                    self.state = Guard::Following {
                        track: key,
                        remaining: Duration::MAX,
                    };
                    return self.observe(snap, now);
                }
                false
            }
            Guard::Following { track, .. } => {
                if key != *track {
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
                };
                false
            }
        }
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

/// Polls the backend and applies requests until the sender side is dropped.
/// Takes the receiver by reference so a supervisor can restart it after a panic.
pub fn run(
    mut backend: impl Backend,
    commands: &Receiver<Request>,
    shared: Arc<Mutex<Snapshot>>,
    poll: Duration,
) {
    let mut notice: Option<(String, Instant)> = None;
    let mut guard = StopAtEnd::default();
    loop {
        let mut snapshot = backend.snapshot().unwrap_or_else(Snapshot::failed);
        if guard.observe(&snapshot, Instant::now())
            && let Err(message) = backend.toggle_play_pause()
        {
            notice = Some((message, Instant::now()));
        }
        notice = notice.filter(|(_, since)| since.elapsed() < NOTICE_HOLD);
        snapshot.notice = notice.as_ref().map(|(message, _)| message.clone());
        *lock(&shared) = snapshot;

        let wait = guard.wake_in().map_or(poll, |w| w.min(poll));
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
                        let started = backend.play_uri(&uri);
                        if started.is_ok() {
                            guard.arm(&lock(&shared), Instant::now());
                        }
                        started
                    }
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
