//! A live oscilloscope of what Spotify is playing right now: the last ~25 ms of the actual
//! waveform, redrawn many times a second as a line that stays in place and moves with the sound.
//! Only this tiny window is ever held, never the audio itself beyond it.

use std::collections::VecDeque;
use std::time::{Duration, Instant};

/// Samples kept: 25 ms at 48 kHz, mono.
pub const WINDOW: usize = 1_200;
/// No new samples for this long means nothing is playing: the line goes flat.
const STALE: Duration = Duration::from_millis(300);
/// The loudest sample is never treated as quieter than this, so near-silence is not blown up.
const MIN_REFERENCE: f32 = 0.05;
/// How much of the reference is kept per push: it follows loud passages down slowly, so a quiet
/// intro and a loud chorus both use the box.
const REFERENCE_DECAY: f32 = 0.998;

/// Averages interleaved 16-bit stereo into mono floats in -1.0..=1.0 (a trailing odd sample is ignored).
pub fn mono_from_i16_stereo(interleaved: &[i16], out: &mut Vec<f32>) {
    out.extend(interleaved.chunks_exact(2).map(|lr| (lr[0] as f32 + lr[1] as f32) / 65_536.0));
}

#[derive(Default)]
pub struct Scope {
    window: VecDeque<f32>,
    reference: f32,
    last_push: Option<Instant>,
}

impl Scope {
    /// Newest samples, in order. Only the last `WINDOW` are kept.
    pub fn push(&mut self, samples: &[f32], now: Instant) {
        let mut loudest = 0.0f32;
        for s in samples {
            let s = if s.is_finite() { s.clamp(-1.0, 1.0) } else { 0.0 };
            loudest = loudest.max(s.abs());
            if self.window.len() == WINDOW {
                self.window.pop_front();
            }
            self.window.push_back(s);
        }
        self.reference = loudest.max(self.reference * REFERENCE_DECAY);
        self.last_push = Some(now);
    }

    pub fn is_live(&self, now: Instant) -> bool {
        self.last_push.is_some_and(|t| now.saturating_duration_since(t) <= STALE)
    }

    /// The window reduced to `points` values in -1.0..=1.0, scaled to the recent loudness. Each
    /// value is the sample with the largest swing in its slice, so peaks survive the reduction.
    /// A flat line when nothing is playing.
    pub fn trace(&self, points: usize, now: Instant) -> Vec<f32> {
        if points == 0 {
            return Vec::new();
        }
        if !self.is_live(now) || self.window.is_empty() {
            return vec![0.0; points];
        }
        let reference = self.reference.max(MIN_REFERENCE);
        let len = self.window.len();
        (0..points)
            .map(|i| {
                let from = i * len / points;
                let to = ((i + 1) * len / points).max(from + 1).min(len);
                let swing = self.window.range(from..to).copied().fold(0.0f32, |best, s| if s.abs() > best.abs() { s } else { best });
                (swing / reference).clamp(-1.0, 1.0)
            })
            .collect()
    }
}

#[cfg(test)]
mod tests;
