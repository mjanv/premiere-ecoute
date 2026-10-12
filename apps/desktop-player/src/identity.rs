//! The `uri` the backend wants in every snapshot. Windows media controls do not expose Spotify's
//! track URI, and the backend detects track changes by comparing `uri`, so the player has to
//! supply something that changes exactly when the track changes.
//!
//! - After the player started a track itself (`play_uri`), the next track change takes that URI.
//! - Otherwise the identity is a `spotify:local:artist:album:title:seconds` string built from what
//!   Windows reports. It is not a real track URI; the backend must not look it up.
//!
//! PROTOCOL-ASSUMPTION: the backend accepts any string in `uri` and only compares it for change.

use std::time::{Duration, Instant};
use url::form_urlencoded::byte_serialize;

/// How long a commanded URI waits for the track change it caused.
const PENDING_TTL: Duration = Duration::from_secs(20);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Identity {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub seconds: u64,
}

fn part(s: &str) -> String {
    byte_serialize(s.as_bytes()).collect()
}

pub fn synthetic_uri(id: &Identity) -> String {
    format!("spotify:local:{}:{}:{}:{}", part(&id.artist), part(&id.album), part(&id.title), id.seconds)
}

#[derive(Default)]
pub struct UriTracker {
    pending: Option<(String, Instant)>,
    last: Option<Identity>,
    current: Option<String>,
}

impl UriTracker {
    /// The player just asked Spotify to play `uri`.
    pub fn commanded(&mut self, uri: String, now: Instant) {
        self.pending = Some((uri, now));
    }

    /// Spotify is not running or has no track.
    pub fn forget(&mut self) {
        self.last = None;
        self.current = None;
    }

    /// The URI for what Windows currently reports; `None` when there is no track.
    pub fn observe(&mut self, id: Identity, now: Instant) -> Option<String> {
        if id.title.is_empty() {
            return None;
        }
        if self.last.as_ref() != Some(&id) {
            let commanded = self.pending.take().filter(|(_, at)| now.duration_since(*at) < PENDING_TTL);
            self.current = Some(commanded.map(|(uri, _)| uri).unwrap_or_else(|| synthetic_uri(&id)));
            self.last = Some(id);
        }
        self.current.clone()
    }
}

#[cfg(test)]
mod tests;
