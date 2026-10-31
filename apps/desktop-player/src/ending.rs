//! How a commanded track ends, as everyone else sees it.
//!
//! With the Web API a track plays alone and stops at its end, and the backend learns that from a
//! state that goes from playing near the end to not playing. The desktop app instead carries on
//! with the next album track, so the player pauses at the end (`StopAtEnd`, `Backend::pause`).
//! This keeps that invisible: once the pause is made, the commanded track is reported
//!
//! 1. playing at its very end, for longer than a snapshot interval, so the backend sees the
//!    "99% or more" state it waits for, even for a short track or an unlucky sampling;
//! 2. then paused at its end, for as long as Spotify stays paused.
//!
//! If Spotify moves on to the next track anyway (a late pause, a pause it ignored), that track is
//! paused again and never reported. The hiding stops when the user plays something (after a
//! short window), when Spotify closes, or when a new track is commanded.

use crate::player::{Playback, Snapshot, same_track};
use std::time::{Duration, Instant};

/// How long the track is still reported as playing at its end. More than the 1 s between two
/// snapshots, so at least one goes out with it.
const HOLD: Duration = Duration::from_millis(1500);
/// After the pause, Spotify playing again within this time is a leak to stop, not the user.
const LEAK_WINDOW: Duration = Duration::from_secs(4);
/// Minimum time between two pauses of the same leak.
const RETRY_EVERY: Duration = Duration::from_millis(250);
/// Pauses attempted for one end, the first included.
const MAX_PAUSES: u8 = 5;
/// How often the loop looks while the end is being hidden.
const WATCH: Duration = Duration::from_millis(200);

fn same(a: &Snapshot, b: &Snapshot) -> bool {
    same_track(
        &(a.title.clone(), a.artist.clone(), a.length),
        &(b.title.clone(), b.artist.clone(), b.length),
    )
}

#[derive(Default)]
enum Phase {
    #[default]
    Idle,
    Active {
        /// The commanded track at its very end.
        shown: Box<Snapshot>,
        since: Instant,
        pauses: u8,
        last_try: Instant,
    },
}

#[derive(Default)]
pub struct Ending {
    /// The last snapshot of the track being followed.
    remembered: Option<Snapshot>,
    phase: Phase,
}

impl Ending {
    /// Call with every snapshot of the track the guard follows.
    pub fn remember(&mut self, snapshot: &Snapshot) {
        self.remembered = Some(snapshot.clone());
    }

    /// The pause was just made (or the end was missed and the next track is being paused).
    pub fn begin(&mut self, now: Instant) {
        let Some(last) = &self.remembered else {
            return;
        };
        let mut shown = last.clone();
        shown.position = shown.length;
        shown.playback = Playback::Playing;
        shown.notice = None;
        shown.error = None;
        self.phase = Phase::Active {
            shown: Box::new(shown),
            since: now,
            pauses: 1,
            last_try: now,
        };
    }

    /// A new track was commanded: forget the previous end.
    pub fn clear(&mut self) {
        self.remembered = None;
        self.phase = Phase::Idle;
    }

    #[cfg(test)]
    fn active(&self) -> bool {
        matches!(self.phase, Phase::Active { .. })
    }

    /// Replaces `real` by what the rest of the system should see, and returns true when Spotify
    /// has to be paused again. `idempotent` says whether pausing a track that already paused is
    /// harmless: only then is the same track paused again (a toggle would resume it).
    pub fn apply(&mut self, real: &mut Snapshot, now: Instant, idempotent: bool) -> bool {
        let Phase::Active {
            shown,
            since,
            pauses,
            last_try,
        } = &mut self.phase
        else {
            return false;
        };
        if !real.running || real.error.is_some() {
            self.phase = Phase::Idle;
            return false;
        }
        let elapsed = now.saturating_duration_since(*since);
        let mut pause_again = false;
        if real.playback == Playback::Playing {
            if elapsed >= LEAK_WINDOW || *pauses >= MAX_PAUSES {
                // The user, or a Spotify that will not stay paused: stop hiding what is real.
                self.phase = Phase::Idle;
                return false;
            }
            let same = same(real, shown);
            if (!same || idempotent) && now.saturating_duration_since(*last_try) >= RETRY_EVERY {
                *pauses += 1;
                *last_try = now;
                pause_again = true;
            }
        }
        let mut view = (**shown).clone();
        view.playback = if elapsed < HOLD {
            Playback::Playing
        } else {
            Playback::Paused
        };
        view.volume = real.volume;
        *real = view;
        pause_again
    }

    /// How long the loop may sleep: short while the end is being hidden, so a leak is caught fast.
    pub fn wake_in(&self, now: Instant) -> Option<Duration> {
        match &self.phase {
            Phase::Active { since, .. } if now.saturating_duration_since(*since) < LEAK_WINDOW => {
                Some(WATCH)
            }
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests;
