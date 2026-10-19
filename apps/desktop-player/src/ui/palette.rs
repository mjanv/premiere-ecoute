//! A palette derived from one cover tint. Contrast is enforced, not hoped for.

use crate::artwork::Tint;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rgb(pub u8, pub u8, pub u8);

impl Rgb {
    pub fn hex(self) -> u32 {
        ((self.0 as u32) << 16) | ((self.1 as u32) << 8) | self.2 as u32
    }

    pub(crate) fn luminance(self) -> f32 {
        let lin = |c: u8| {
            let c = c as f32 / 255.0;
            if c <= 0.03928 {
                c / 12.92
            } else {
                ((c + 0.055) / 1.055).powf(2.4)
            }
        };
        0.2126 * lin(self.0) + 0.7152 * lin(self.1) + 0.0722 * lin(self.2)
    }
}

/// WCAG contrast ratio, 1.0..=21.0.
pub fn contrast(a: Rgb, b: Rgb) -> f32 {
    let (la, lb) = (a.luminance(), b.luminance());
    (la.max(lb) + 0.05) / (la.min(lb) + 0.05)
}

fn hsl(h: f32, s: f32, l: f32) -> Rgb {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = l - c / 2.0;
    let (r, g, b) = match (h.rem_euclid(360.0) / 60.0) as u32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let to = |v: f32| ((v + m) * 255.0).round().clamp(0.0, 255.0) as u8;
    Rgb(to(r), to(g), to(b))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Palette {
    /// Top of the window gradient.
    pub bg: Rgb,
    /// Bottom of the window gradient, from the cover's second colour.
    pub bg_end: Rgb,
    pub surface: Rgb,
    pub ink: Rgb,
    pub muted: Rgb,
    pub accent: Rgb,
    /// Problems; fixed hue so it never blends into a cover's own colour.
    pub warn: Rgb,
    /// Glyph colour on top of `accent`.
    pub on_accent: Rgb,
}

/// Neutral slate used when there is no cover.
const FALLBACK_HUE: f32 = 215.0;

impl Palette {
    pub fn from_tint(tint: Option<Tint>) -> Self {
        let (hue, sat) = match tint {
            Some(t) if t.saturation > 0.05 => (t.hue, t.saturation),
            _ => (FALLBACK_HUE, 0.0),
        };
        // How much of the cover's colour reaches the surfaces; grey covers stay neutral.
        let k = (sat / 0.6).min(1.0);
        let bg = hsl(hue, 0.04 + 0.45 * k, 0.09);
        // Second colour of the cover; a nearby hue when the cover has only one.
        let end_hue = match tint {
            Some(t) if sat > 0.05 => t.second_hue.unwrap_or(hue + 70.0),
            _ => hue,
        };
        // As light as the hue allows: greens and yellows are brighter than blues at equal lightness.
        let end_sat = 0.06 + 0.60 * k;
        let mut end_l = 0.17;
        while hsl(end_hue, end_sat, end_l).luminance() > 0.03 {
            end_l -= 0.01;
        }
        let bg_end = hsl(end_hue, end_sat, end_l);
        let surface = hsl(hue, 0.04 + 0.26 * k, 0.135);
        let ink = hsl(hue, 0.10 + 0.20 * k, 0.94);
        let muted = lift(hue, 0.08 + 0.12 * k, 0.66, bg_end, 4.5);
        let accent_sat = if sat > 0.05 {
            (0.55 + 0.4 * sat).min(0.95)
        } else {
            0.45
        };
        let accent_hue = if sat > 0.05 { hue } else { 38.0 }; // sodium amber on a grey cover
        let accent = lift(accent_hue, accent_sat, 0.62, bg_end, 4.5);
        let on_accent = if contrast(bg, accent) >= contrast(ink, accent) {
            bg
        } else {
            ink
        };
        Self {
            bg,
            bg_end,
            surface,
            ink,
            muted,
            accent,
            warn: Rgb(0xFF, 0x9A, 0x7A),
            on_accent,
        }
    }
}

/// Raises lightness until the colour reaches `min` contrast against `against`.
fn lift(h: f32, s: f32, mut l: f32, against: Rgb, min: f32) -> Rgb {
    loop {
        let c = hsl(h, s, l);
        if contrast(c, against) >= min || l >= 0.95 {
            return c;
        }
        l += 0.02;
    }
}

#[cfg(test)]
mod tests;
