//! Cover art: format sniffing and the dominant tint that drives the UI palette.

use std::hash::{Hash, Hasher};
use std::sync::Arc;

/// Dominant colour of a cover. Grey covers have `saturation == 0.0`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Tint {
    /// Degrees, 0..360.
    pub hue: f32,
    /// 0.0..=1.0
    pub saturation: f32,
}

#[derive(Clone, PartialEq)]
pub struct Artwork {
    pub bytes: Arc<[u8]>,
    pub tint: Tint,
    /// Stable per image content, lets the UI cache the decoded image.
    pub id: u64,
}

impl std::fmt::Debug for Artwork {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Artwork {{ id: {}, {} bytes }}",
            self.id,
            self.bytes.len()
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Format {
    Png,
    Jpeg,
}

pub fn sniff(bytes: &[u8]) -> Option<Format> {
    if bytes.starts_with(&[0x89, b'P', b'N', b'G']) {
        Some(Format::Png)
    } else if bytes.starts_with(&[0xFF, 0xD8, 0xFF]) {
        Some(Format::Jpeg)
    } else {
        None
    }
}

const BINS: usize = 24;
/// Pixels that are too dark or too grey say nothing about a cover's colour.
const MIN_SATURATION: f32 = 0.15;
const MIN_VALUE: f32 = 0.15;
/// Below this share of coloured pixels, the cover counts as grey.
const MIN_COLOURED_SHARE: f32 = 0.02;

/// Dominant tint of RGBA8 pixels: the hue bin with the most (saturation x value) weight.
pub fn tint_from_rgba(pixels: &[u8]) -> Tint {
    let mut weight = [0f32; BINS];
    let mut sin = [0f32; BINS];
    let mut cos = [0f32; BINS];
    let mut sat = [0f32; BINS];
    let mut total = 0usize;
    let mut coloured = 0usize;

    for px in pixels.as_chunks::<4>().0 {
        total += 1;
        let (h, s, v) = rgb_to_hsv(px[0], px[1], px[2]);
        if s < MIN_SATURATION || v < MIN_VALUE {
            continue;
        }
        coloured += 1;
        let w = s * v;
        let bin = ((h / 360.0 * BINS as f32) as usize).min(BINS - 1);
        let rad = h.to_radians();
        weight[bin] += w;
        sin[bin] += w * rad.sin();
        cos[bin] += w * rad.cos();
        sat[bin] += w * s;
    }

    if total == 0 || (coloured as f32 / total as f32) < MIN_COLOURED_SHARE {
        return Tint {
            hue: 0.0,
            saturation: 0.0,
        };
    }
    let best = (0..BINS)
        .max_by(|&a, &b| weight[a].total_cmp(&weight[b]))
        .unwrap_or(0);
    let hue = sin[best].atan2(cos[best]).to_degrees().rem_euclid(360.0);
    Tint {
        hue,
        saturation: (sat[best] / weight[best]).clamp(0.0, 1.0),
    }
}

fn rgb_to_hsv(r: u8, g: u8, b: u8) -> (f32, f32, f32) {
    let (r, g, b) = (r as f32 / 255.0, g as f32 / 255.0, b as f32 / 255.0);
    let max = r.max(g).max(b);
    let delta = max - r.min(g).min(b);
    let hue = if delta == 0.0 {
        0.0
    } else if max == r {
        60.0 * ((g - b) / delta).rem_euclid(6.0)
    } else if max == g {
        60.0 * ((b - r) / delta + 2.0)
    } else {
        60.0 * ((r - g) / delta + 4.0)
    };
    (hue, if max == 0.0 { 0.0 } else { delta / max }, max)
}

impl Artwork {
    /// Accepts PNG or JPEG bytes; `None` when the bytes are not a decodable image.
    pub fn from_bytes(bytes: Vec<u8>) -> Option<Self> {
        sniff(&bytes)?;
        let decoded = image::load_from_memory(&bytes).ok()?;
        let small = image::imageops::thumbnail(&decoded.to_rgba8(), 32, 32);
        let tint = tint_from_rgba(small.as_raw());
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        bytes.hash(&mut hasher);
        Some(Self {
            id: hasher.finish(),
            bytes: bytes.into(),
            tint,
        })
    }
}

#[cfg(test)]
mod tests;
