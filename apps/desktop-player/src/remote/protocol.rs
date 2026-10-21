//! The wire protocol of `docs/guides/desktop-player.md` in the monorepo root (Phoenix V2 JSON
//! frames on the topic `desktop:me`). Everything that knows an event name or a JSON shape lives
//! here; the rest of the player sees only `Inbound` and `Outbound`-style neutral types.
//!
//! The backend guide is the authority. This file is pure: no I/O, no clock.

use crate::player::{Command, Playback, Repeat, Snapshot};
use crate::remote_status::Outcome;
use crate::remote_status::{SessionInfo, SessionState};
use serde_json::{Value, json};
use std::time::Duration;

pub const TOPIC: &str = "desktop:me";
pub const PROTO: u32 = 1;
const HEARTBEAT_TOPIC: &str = "phoenix";
const MAX_TEXT: usize = 512;
/// No album has more tracks than this.
const MAX_TRACK_NUMBER: u64 = 999;
const MAX_GENRES: usize = 10;
const DEFAULT_TTL: Duration = Duration::from_millis(10_000);
const MAX_TTL: Duration = Duration::from_secs(60);

#[derive(Clone, Debug, PartialEq)]
pub struct Frame {
    pub join_ref: Option<String>,
    pub msg_ref: Option<String>,
    pub topic: String,
    pub event: String,
    pub payload: Value,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BadFrame(pub String);

pub fn decode_frame(text: &str) -> Result<Frame, BadFrame> {
    let value: Value = serde_json::from_str(text).map_err(|e| BadFrame(e.to_string()))?;
    let [join_ref, msg_ref, topic, event, payload] = value
        .as_array()
        .map(Vec::as_slice)
        .and_then(|a| <&[Value; 5]>::try_from(a).ok())
        .ok_or_else(|| BadFrame("expected a 5 element array".into()))?
        .clone();
    let opt = |v: &Value| match v {
        Value::Null => Ok(None),
        Value::String(s) => Ok(Some(s.clone())),
        _ => Err(BadFrame("ref must be a string or null".into())),
    };
    let text = |v: &Value, what: &str| {
        v.as_str()
            .map(str::to_string)
            .ok_or_else(|| BadFrame(format!("{what} must be a string")))
    };
    Ok(Frame {
        join_ref: opt(&join_ref)?,
        msg_ref: opt(&msg_ref)?,
        topic: text(&topic, "topic")?,
        event: text(&event, "event")?,
        payload,
    })
}

pub fn encode_frame(f: &Frame) -> String {
    json!([f.join_ref, f.msg_ref, f.topic, f.event, f.payload]).to_string()
}

// ---- outbound ------------------------------------------------------------------------------

fn frame(join_ref: &str, msg_ref: u64, event: &str, payload: Value) -> String {
    encode_frame(&Frame {
        join_ref: Some(join_ref.to_string()),
        msg_ref: Some(msg_ref.to_string()),
        topic: TOPIC.into(),
        event: event.into(),
        payload,
    })
}

pub fn join(join_ref: &str, session_id: &str, app_version: &str) -> String {
    frame(
        join_ref,
        1,
        "phx_join",
        json!({"proto": PROTO, "app_version": app_version, "session_id": session_id}),
    )
}

pub fn heartbeat(msg_ref: u64) -> String {
    encode_frame(&Frame {
        join_ref: None,
        msg_ref: Some(msg_ref.to_string()),
        topic: HEARTBEAT_TOPIC.into(),
        event: "heartbeat".into(),
        payload: json!({}),
    })
}

fn cut(s: &str) -> String {
    s.chars().take(MAX_TEXT).collect()
}

pub fn snapshot(join_ref: &str, msg_ref: u64, seq: u64, s: &Snapshot) -> String {
    let playback = match s.playback {
        Playback::Playing => "playing",
        Playback::Paused => "paused",
        Playback::Stopped => "stopped",
    };
    // Spotify not running: say so and send no track identity (the backend then reports "no device").
    let uri = if s.running {
        s.uri.as_deref().map(cut)
    } else {
        None
    };
    frame(
        join_ref,
        msg_ref,
        "snapshot",
        json!({"seq": seq, "snapshot": {
            "running": s.running,
            "playback": playback,
            "uri": uri,
            "title": cut(&s.title),
            "artist": cut(&s.artist),
            "album": cut(&s.album),
            "album_artist": cut(&s.album_artist),
            "track_number": s.track_number,
            "album_track_count": s.album_track_count,
            "genres": s.genres.iter().take(MAX_GENRES).map(|g| cut(g)).collect::<Vec<_>>(),
            "shuffle": s.shuffle,
            "repeat": s.repeat.map(Repeat::wire),
            "position_ms": s.position.as_millis() as u64,
            "length_ms": s.length.as_millis() as u64,
            "volume": s.volume,
        }}),
    )
}

impl Repeat {
    pub fn wire(self) -> &'static str {
        match self {
            Repeat::None => "none",
            Repeat::Track => "track",
            Repeat::List => "list",
        }
    }
}

impl Outcome {
    pub fn wire(self) -> &'static str {
        match self {
            Outcome::Ok => "ok",
            Outcome::Error => "error",
            Outcome::Rejected => "rejected",
            Outcome::Expired => "expired",
            Outcome::Duplicate => "duplicate",
        }
    }
}

pub fn ack(
    join_ref: &str,
    msg_ref: u64,
    command_id: &str,
    outcome: Outcome,
    error: Option<&str>,
) -> String {
    let mut payload = json!({"command_id": command_id, "status": outcome.wire()});
    if let Some(e) = error {
        payload["error"] = json!(cut(e));
    }
    frame(join_ref, msg_ref, "ack", payload)
}

// ---- inbound -------------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
pub struct RemoteCommand {
    pub id: String,
    pub name: String,
    pub command: Command,
    pub ttl: Duration,
}

/// A command that failed validation. With an id the player acks `rejected`; without one it cannot.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Rejection {
    pub id: Option<String>,
    pub reason: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Disconnect {
    /// Another connection of the same user took over.
    Replaced,
    /// The user disconnected the player or the tokens were revoked.
    Revoked,
    Other(String),
}

#[derive(Clone, Debug, PartialEq)]
pub enum Inbound {
    JoinOk {
        snapshot_interval: Duration,
    },
    JoinRefused {
        reason: String,
    },
    HeartbeatReply,
    Command(Result<RemoteCommand, Rejection>),
    Disconnect(Disconnect),
    /// Whether the streamer has a listening session.
    Session(SessionInfo),
    /// The channel ended (`phx_close` or `phx_error`).
    ChannelEnded,
    /// Unknown events and replies we do not care about.
    Ignored,
}

pub fn interpret(f: &Frame) -> Inbound {
    match (f.topic.as_str(), f.event.as_str()) {
        (HEARTBEAT_TOPIC, "phx_reply") => Inbound::HeartbeatReply,
        (TOPIC, "phx_reply") => join_reply(&f.payload),
        (TOPIC, "command") => Inbound::Command(command(&f.payload)),
        (TOPIC, "disconnect") => Inbound::Disconnect(match f.payload["reason"].as_str() {
            Some("replaced") => Disconnect::Replaced,
            Some("revoked") => Disconnect::Revoked,
            other => Disconnect::Other(other.unwrap_or("unknown").to_string()),
        }),
        (TOPIC, "session") => session(&f.payload).map_or(Inbound::Ignored, Inbound::Session),
        (TOPIC, "phx_close" | "phx_error") => Inbound::ChannelEnded,
        _ => Inbound::Ignored,
    }
}

/// `None` when the state is missing or unknown: a server newer than the player may add states.
fn session(p: &Value) -> Option<SessionInfo> {
    let state = match p["state"].as_str()? {
        "none" => SessionState::None,
        "preparing" => SessionState::Preparing,
        "active" => SessionState::Active,
        _ => return None,
    };
    let count = |key: &str| {
        p[key]
            .as_u64()
            .filter(|n| *n > 0)
            .and_then(|n| u32::try_from(n).ok())
    };
    Some(SessionInfo {
        state,
        source: p["source"].as_str().map(cut),
        name: p["name"].as_str().map(cut),
        track_number: count("track_number"),
        track_count: count("track_count"),
    })
}

fn join_reply(payload: &Value) -> Inbound {
    match payload["status"].as_str() {
        Some("ok") => {
            let ms = payload["response"]["snapshot_interval_ms"]
                .as_u64()
                .unwrap_or(1_000)
                .clamp(500, 30_000);
            Inbound::JoinOk {
                snapshot_interval: Duration::from_millis(ms),
            }
        }
        Some("error") => Inbound::JoinRefused {
            reason: payload["response"]["reason"]
                .as_str()
                .unwrap_or("unknown")
                .to_string(),
        },
        _ => Inbound::Ignored,
    }
}

/// `spotify:track:` followed by 22 alphanumeric characters, nothing else (links are not accepted
/// from the backend).
fn strict_track_uri(uri: &str) -> bool {
    uri.strip_prefix("spotify:track:")
        .is_some_and(|id| id.len() == 22 && id.chars().all(|c| c.is_ascii_alphanumeric()))
}

fn command(p: &Value) -> Result<RemoteCommand, Rejection> {
    let id = p["id"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    let reject = |reason: &str| Rejection {
        id: id.clone(),
        reason: reason.into(),
    };
    let Some(command_id) = id.clone() else {
        return Err(reject("missing command id"));
    };

    let args = &p["args"];
    let (name, command) = match p["type"].as_str() {
        Some("toggle_play_pause") => ("toggle_play_pause", Command::TogglePlayPause),
        Some("next") => ("next", Command::Next),
        Some("previous") => ("previous", Command::Previous),
        Some("set_volume") => {
            let v = args["volume"]
                .as_f64()
                .filter(|v| v.is_finite() && (0.0..=1.0).contains(v));
            (
                "set_volume",
                Command::SetVolume(
                    v.ok_or_else(|| reject("volume must be a number from 0 to 1"))? as f32,
                ),
            )
        }
        Some("play_uri") => {
            let uri = args["uri"]
                .as_str()
                .filter(|u| strict_track_uri(u))
                .ok_or_else(|| reject("uri must be spotify:track: and 22 letters or digits"))?
                .to_string();
            // The position of the track in its album, when the backend knows it. One that makes
            // no sense is ignored: the track still plays, only unchecked.
            let number = args["track_number"]
                .as_u64()
                .filter(|n| (1..=MAX_TRACK_NUMBER).contains(n))
                .and_then(|n| u32::try_from(n).ok());
            (
                "play_uri",
                match number {
                    Some(number) => Command::PlayTrack { uri, number },
                    None => Command::PlayUri(uri),
                },
            )
        }
        Some(_) => return Err(reject("unknown command type")),
        None => return Err(reject("missing command type")),
    };
    let ttl = p["ttl_ms"]
        .as_u64()
        .map(Duration::from_millis)
        .unwrap_or(DEFAULT_TTL)
        .min(MAX_TTL);
    Ok(RemoteCommand {
        id: command_id,
        name: name.into(),
        command,
        ttl,
    })
}

#[cfg(test)]
mod tests;
