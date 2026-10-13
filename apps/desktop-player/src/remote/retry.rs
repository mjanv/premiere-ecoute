//! Reconnect delays and command-id memory.

use std::collections::{HashSet, VecDeque};
use std::time::Duration;

const BASE: Duration = Duration::from_secs(1);
const CAP: Duration = Duration::from_secs(60);
/// Never reconnect in a tight loop, even when the random draw is tiny.
const FLOOR: Duration = Duration::from_millis(250);

/// Exponential backoff with full jitter: `random(0, min(60 s, 1 s * 2^attempt))`.
/// Full jitter spreads a whole fleet reconnecting after a backend restart.
#[derive(Default)]
pub struct Backoff {
    attempt: u32,
}

impl Backoff {
    /// `unit` is a random number in `0.0..=1.0`.
    pub fn next_delay(&mut self, unit: f64) -> Duration {
        let ceiling = (BASE * 2u32.saturating_pow(self.attempt.min(16))).min(CAP);
        self.attempt = self.attempt.saturating_add(1);
        ceiling.mul_f64(unit.clamp(0.0, 1.0)).max(FLOOR)
    }

    pub fn reset(&mut self) {
        self.attempt = 0;
    }
}

/// The last N command ids seen, so a repeated id is acknowledged but never run twice.
pub struct SeenIds {
    order: VecDeque<String>,
    ids: HashSet<String>,
    cap: usize,
}

impl SeenIds {
    pub fn new(cap: usize) -> Self {
        Self {
            order: VecDeque::new(),
            ids: HashSet::new(),
            cap,
        }
    }

    /// Records the id; `false` when it was already there.
    pub fn insert(&mut self, id: &str) -> bool {
        if !self.ids.insert(id.to_string()) {
            return false;
        }
        self.order.push_back(id.to_string());
        if self.order.len() > self.cap
            && let Some(old) = self.order.pop_front()
        {
            self.ids.remove(&old);
        }
        true
    }
}

#[cfg(test)]
mod tests;
