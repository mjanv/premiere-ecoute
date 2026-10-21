//! One colour for "will the listening session work?", glanceable from the taskbar while the window
//! is minimized behind the streamer's other software.
//!
//! Playing or paused deliberately does not count: a paused track mid-session is normal, and a
//! light that flickers with it would be useless at a glance.

use crate::player::Snapshot;
use crate::remote_status::{Link, RemoteStatus};
use std::time::{Duration, Instant};

/// The backend falls back to polling Spotify when no snapshot arrives for this long, so a player
/// that has sent nothing for longer is not really linked, whatever the connection says.
pub const STALE_AFTER: Duration = Duration::from_secs(5);

/// Whether a snapshot went out recently enough for the backend to still follow this player.
pub fn sending(remote: &RemoteStatus, now: Instant) -> bool {
    remote
        .exchange
        .last_snapshot_at
        .is_some_and(|at| now.saturating_duration_since(at) <= STALE_AFTER)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Light {
    /// Linked to the backend, sending, and Spotify is running.
    Green,
    /// On its way or recoverable: signing in, connecting, retrying, nothing sent lately, or Spotify is not running.
    Amber,
    /// Needs the streamer: login rejected, backend error, or the player cannot read Spotify.
    Red,
    /// Local only: nothing is expected to reach the backend.
    Grey,
}

impl Light {
    pub fn of(snapshot: &Snapshot, remote: &RemoteStatus, now: Instant) -> Self {
        if snapshot.error.is_some() {
            return Light::Red;
        }
        match remote.link {
            Link::Disabled => Light::Grey,
            Link::Unauthorized | Link::Failed(_) => Light::Red,
            Link::SigningIn | Link::Connecting | Link::Offline { .. } => Light::Amber,
            Link::Connected if snapshot.running && sending(remote, now) => Light::Green,
            Link::Connected => Light::Amber,
        }
    }

    pub fn rgb(self) -> [u8; 3] {
        match self {
            Light::Green => [0x2e, 0xcc, 0x71],
            Light::Amber => [0xf5, 0xa6, 0x23],
            Light::Red => [0xe7, 0x4c, 0x3c],
            Light::Grey => [0x8a, 0x8f, 0x98],
        }
    }

    /// Read by screen readers and shown by Windows as the badge's description.
    pub fn description(self) -> &'static str {
        match self {
            Light::Green => "Linked to the server, Spotify running",
            Light::Amber => "Not ready, waiting for the server or Spotify",
            Light::Red => "Needs attention, open the player",
            Light::Grey => "Local only, not linked to a server",
        }
    }
}

#[cfg(test)]
mod tests;
