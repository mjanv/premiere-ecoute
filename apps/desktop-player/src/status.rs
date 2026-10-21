//! What the window tells the streamer about the link: a verdict and a checklist, each row one
//! thing that has to be true for a listening session to work. Pure: the window only draws it.
//!
//! The window draws whatever rows it is given ("the server heard us" would be one more). The
//! listening session the backend reports is not a row but a section of its own, `session_view`.

use crate::light::{self, Light};
use crate::player::Snapshot;
use crate::remote_status::{Link, Outcome, RemoteStatus, SessionInfo, SessionState, Tone};
use std::time::Instant;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CheckState {
    Ok,
    /// On its way: nothing to do but wait, or a step for the streamer.
    Wait,
    Bad,
    /// Not applicable now, or nothing to report yet.
    Off,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Check {
    pub label: &'static str,
    pub state: CheckState,
    pub detail: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Verdict {
    pub light: Light,
    pub title: &'static str,
    pub hint: String,
}

fn check(label: &'static str, state: CheckState, detail: impl Into<String>) -> Check {
    Check {
        label,
        state,
        detail: detail.into(),
    }
}

fn server(remote: &RemoteStatus) -> Check {
    let detail = match &remote.link {
        Link::Connected => "Linked".to_string(),
        Link::Connecting => "Connecting".to_string(),
        Link::SigningIn => "Waiting for the browser".to_string(),
        Link::Offline { retry_in } => format!("Offline, retry in {} s", retry_in.as_secs().max(1)),
        Link::Unauthorized => "Sign in again".to_string(),
        Link::Failed(reason) => format!("Error: {reason}"),
        Link::Disabled => "Not linked".to_string(),
    };
    let state = match (remote.link.tone(), &remote.link) {
        (Tone::Good, _) => CheckState::Ok,
        (Tone::Warn, _) => CheckState::Bad,
        (Tone::Idle, Link::Disabled) => CheckState::Off,
        (Tone::Idle, _) => CheckState::Wait,
    };
    check("Server", state, detail)
}

fn spotify(snapshot: &Snapshot) -> Check {
    if let Some(error) = &snapshot.error {
        return check(
            "Spotify",
            CheckState::Bad,
            format!("Can't read it: {error}"),
        );
    }
    if !snapshot.running {
        return check("Spotify", CheckState::Wait, "Not running. Open Spotify");
    }
    // Open: playing, paused or stopped, as the player names them.
    let state = snapshot.state_label();
    check("Spotify", CheckState::Ok, state)
}

fn data(remote: &RemoteStatus, now: Instant) -> Check {
    if !matches!(remote.link, Link::Connected) {
        return check("Data", CheckState::Off, "Waiting for the server");
    }
    match remote.exchange.last_snapshot_at {
        None => check("Data", CheckState::Wait, "Waiting for the first send"),
        Some(_) if light::sending(remote, now) => check(
            "Data",
            CheckState::Ok,
            upper_first(&remote.exchange.sent_line(now)),
        ),
        Some(at) => {
            let age = crate::remote_status::age_short(now, at);
            check("Data", CheckState::Bad, format!("Nothing sent for {age}"))
        }
    }
}

/// The listening session as the server last reported it, for its own section of the window. It is
/// information: it never decides the verdict, a working link with no session is still ready.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SessionView {
    /// Ok: running. Wait: prepared, not started. Off: none, or not known.
    pub state: CheckState,
    pub headline: &'static str,
    /// `Album · Plantation Lullabies`, or what to do.
    pub subtitle: String,
    /// `4/10`, while a session runs on an album or a playlist.
    pub position: Option<String>,
}

fn source_label(source: &str) -> Option<&'static str> {
    match source {
        "album" => Some("Album"),
        "playlist" => Some("Playlist"),
        "track" => Some("Track"),
        "free" => Some("Free session"),
        "clip" => Some("Clip"),
        // A server newer than the player may add sources: show the name alone.
        _ => None,
    }
}

/// `Album · Plantation Lullabies`; a free session does not repeat its own name.
fn describe(info: &SessionInfo) -> String {
    let label = info.source.as_deref().and_then(source_label);
    let name = info
        .name
        .as_deref()
        .filter(|n| !n.is_empty() && Some(n.to_lowercase()) != label.map(str::to_lowercase));
    label
        .into_iter()
        .chain(name)
        .collect::<Vec<_>>()
        .join(" · ")
}

pub fn session_view(remote: &RemoteStatus) -> SessionView {
    let known = remote
        .session
        .as_ref()
        .filter(|_| matches!(remote.link, Link::Connected));
    let Some(info) = known else {
        return SessionView {
            state: CheckState::Off,
            headline: "UNKNOWN",
            subtitle: "Waiting for the server".into(),
            position: None,
        };
    };
    match info.state {
        SessionState::None => SessionView {
            state: CheckState::Off,
            headline: "NO SESSION",
            subtitle: "Start one from the dashboard".into(),
            position: None,
        },
        SessionState::Preparing => SessionView {
            state: CheckState::Wait,
            headline: "READY TO START",
            subtitle: describe(info),
            position: None,
        },
        SessionState::Active => SessionView {
            state: CheckState::Ok,
            headline: "RUNNING",
            subtitle: describe(info),
            position: match (info.track_number, info.track_count) {
                (Some(n), Some(of)) => Some(format!("{n}/{of}")),
                (Some(n), None) => Some(n.to_string()),
                _ => None,
            },
        },
    }
}

fn commands(remote: &RemoteStatus, now: Instant) -> Check {
    let Some(last) = &remote.exchange.last_command else {
        return check("Commands", CheckState::Off, "None received yet");
    };
    let state = match last.outcome {
        Outcome::Ok | Outcome::Duplicate => CheckState::Ok,
        Outcome::Error | Outcome::Rejected | Outcome::Expired => CheckState::Bad,
    };
    let line = remote.exchange.command_line(now).unwrap_or_default();
    check("Commands", state, line)
}

/// The rows, top to bottom.
pub fn checks(snapshot: &Snapshot, remote: &RemoteStatus, now: Instant) -> Vec<Check> {
    vec![
        server(remote),
        spotify(snapshot),
        data(remote, now),
        commands(remote, now),
    ]
}

/// Rows that decide the light. `Commands` is information: a refused command must not turn a
/// working link red for good.
const DECIDING: [&str; 3] = ["Server", "Spotify", "Data"];

pub fn verdict(snapshot: &Snapshot, remote: &RemoteStatus, now: Instant) -> Verdict {
    let light = Light::of(snapshot, remote, now);
    let title = match light {
        Light::Green => "READY",
        Light::Amber => "WAITING",
        Light::Red => "ACTION NEEDED",
        Light::Grey => "LOCAL ONLY",
    };
    let hint = match light {
        Light::Green => "Linked and sending".to_string(),
        Light::Grey => "Not linked to a server".to_string(),
        Light::Amber | Light::Red => checks(snapshot, remote, now)
            .into_iter()
            .filter(|c| DECIDING.contains(&c.label))
            .find(|c| matches!(c.state, CheckState::Bad | CheckState::Wait))
            .map(|c| format!("{}: {}", c.label, lower_first(&c.detail)))
            .unwrap_or_default(),
    };
    Verdict { light, title, hint }
}

fn upper_first(text: &str) -> String {
    let mut chars = text.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().chain(chars).collect(),
        None => String::new(),
    }
}

/// `Not running` to `not running`, but `Open Spotify` stays: only the first word of a sentence.
fn lower_first(text: &str) -> String {
    let mut chars = text.chars();
    match chars.next() {
        Some(first) => first.to_lowercase().chain(chars).collect(),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests;
