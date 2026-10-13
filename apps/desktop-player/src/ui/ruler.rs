//! The timeline ruler: one tick every few seconds, a long tick per minute, minute numbers.
//! The spacing is real time, so the ruler reads like a tape counter instead of a decoration.

use std::time::Duration;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TickKind {
    Minor,
    Major,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Tick {
    /// Position along the track, 0.0..=1.0.
    pub fraction: f32,
    pub kind: TickKind,
    /// Minute number to print under a major tick.
    pub label: Option<u32>,
}

const STEPS_S: [u64; 7] = [5, 10, 15, 30, 60, 120, 300];
const MAX_TICKS: u64 = 90;
const MINUTE: u64 = 60;

/// The smallest step that keeps the ruler under `MAX_TICKS` ticks.
pub fn tick_step(length: Duration) -> Duration {
    let secs = length.as_secs();
    let step = STEPS_S
        .iter()
        .copied()
        .find(|s| secs / s <= MAX_TICKS)
        .unwrap_or(600);
    Duration::from_secs(step)
}

pub fn ticks(length: Duration) -> Vec<Tick> {
    let total = length.as_secs_f32();
    if length.as_secs() == 0 {
        return Vec::new();
    }
    let step = tick_step(length).as_secs();
    let short = length.as_secs() <= 12 * MINUTE;
    (0..=length.as_secs() / step)
        .map(|k| {
            let at = k * step;
            let major = at.is_multiple_of(MINUTE);
            let label = (major && at > 0 && (short || at.is_multiple_of(5 * MINUTE)))
                .then_some((at / MINUTE) as u32);
            Tick {
                fraction: (at as f32 / total).min(1.0),
                kind: if major {
                    TickKind::Major
                } else {
                    TickKind::Minor
                },
                label,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests;
