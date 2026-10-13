//! What the UI shows about the link to the SaaS backend (ADR 0001).
//! The remote subsystem owns the writes; the UI only reads a snapshot of this value.

use std::time::{Duration, Instant};

#[derive(Clone, Debug, Default, PartialEq)]
pub enum Link {
    /// No backend configured: the player works locally only.
    #[default]
    Disabled,
    /// The browser is open and the app waits for the user to approve.
    SigningIn,
    Connecting,
    Connected,
    Offline {
        retry_in: Duration,
    },
    /// Credentials rejected: the user has to connect the account again.
    Unauthorized,
    Failed(String),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tone {
    Idle,
    Good,
    Warn,
}

/// Result a command ended with, as acknowledged to the backend.
/// Variants are constructed by the remote subsystem (ADR 0001), not yet written.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Outcome {
    Ok,
    Error,
    Rejected,
    Expired,
    Duplicate,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CommandLog {
    pub name: String,
    pub outcome: Outcome,
    pub at: Instant,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Exchange {
    pub snapshots_sent: u64,
    pub last_snapshot_at: Option<Instant>,
    pub last_command: Option<CommandLog>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct RemoteStatus {
    pub link: Link,
    pub exchange: Exchange,
}

impl Link {
    pub fn label(&self) -> String {
        match self {
            Link::Disabled => "Local only".into(),
            Link::SigningIn => "Waiting for the browser".into(),
            Link::Connecting => "Connecting to server".into(),
            Link::Connected => "Server linked".into(),
            Link::Offline { retry_in } => {
                format!("Server offline, retry in {} s", retry_in.as_secs().max(1))
            }
            Link::Unauthorized => "Server: sign in again".into(),
            Link::Failed(reason) => format!("Server error: {reason}"),
        }
    }

    pub fn tone(&self) -> Tone {
        match self {
            Link::Connected => Tone::Good,
            Link::Disabled | Link::SigningIn | Link::Connecting => Tone::Idle,
            Link::Offline { .. } | Link::Unauthorized | Link::Failed(_) => Tone::Warn,
        }
    }
}

/// Compact age for the footer: `now`, `7s`, `3m`, `2h`.
pub fn age_short(now: Instant, then: Instant) -> String {
    let secs = now.saturating_duration_since(then).as_secs();
    match secs {
        0..=1 => "now".into(),
        2..=59 => format!("{secs}s"),
        60..=3599 => format!("{}m", secs / 60),
        _ => format!("{}h", secs / 3600),
    }
}

impl Outcome {
    pub fn label(self) -> &'static str {
        match self {
            Outcome::Ok => "ok",
            Outcome::Error => "failed",
            Outcome::Rejected => "refused",
            Outcome::Expired => "too late",
            Outcome::Duplicate => "ignored",
        }
    }
}

impl Exchange {
    /// `sent 7s`, or `no data sent` before the first snapshot.
    pub fn sent_line(&self, now: Instant) -> String {
        match self.last_snapshot_at {
            None => "no data sent".into(),
            Some(at) => format!("sent {}", age_short(now, at)),
        }
    }

    /// `next, done 18s`; `None` until a command has been received.
    pub fn command_line(&self, now: Instant) -> Option<String> {
        let c = self.last_command.as_ref()?;
        Some(format!(
            "{}, {} {}",
            c.name,
            c.outcome.label(),
            age_short(now, c.at)
        ))
    }
}

impl RemoteStatus {
    /// Fake states for looking at the UI without a backend: `PLAYER_UI_PREVIEW=connected|connecting|offline|unauthorized|failed`.
    pub fn preview(kind: &str, now: Instant) -> Option<Self> {
        let sent = Exchange {
            snapshots_sent: 4312,
            last_snapshot_at: now.checked_sub(Duration::from_secs(1)),
            last_command: now
                .checked_sub(Duration::from_secs(12))
                .map(|at| CommandLog {
                    name: "next".into(),
                    outcome: Outcome::Ok,
                    at,
                }),
        };
        let (link, exchange) = match kind {
            "connected" => (Link::Connected, sent),
            "connecting" => (Link::Connecting, Exchange::default()),
            "offline" => (
                Link::Offline {
                    retry_in: Duration::from_secs(12),
                },
                Exchange {
                    last_snapshot_at: now.checked_sub(Duration::from_secs(95)),
                    ..sent
                },
            ),
            "unauthorized" => (Link::Unauthorized, Exchange::default()),
            "failed" => (
                Link::Failed("server refused protocol 1".into()),
                Exchange::default(),
            ),
            _ => return None,
        };
        Some(Self { link, exchange })
    }
}

#[cfg(test)]
mod tests;
