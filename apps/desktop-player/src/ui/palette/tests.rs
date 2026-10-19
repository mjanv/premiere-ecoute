use super::*;

fn tints() -> impl Iterator<Item = Option<Tint>> {
    let chromatic = (0..360).step_by(15).flat_map(|h| {
        [0.3, 0.7, 1.0].map(|s| {
            Some(Tint {
                hue: h as f32,
                saturation: s,
                second_hue: Some((h as f32 + 150.0) % 360.0),
            })
        })
    });
    chromatic.chain([
        None,
        Some(Tint {
            hue: 0.0,
            saturation: 0.0,
            second_hue: None,
        }),
    ])
}

#[test]
fn contrast_matches_known_values() {
    assert!((contrast(Rgb(0, 0, 0), Rgb(255, 255, 255)) - 21.0).abs() < 0.01);
    assert!((contrast(Rgb(255, 255, 255), Rgb(255, 255, 255)) - 1.0).abs() < 0.01);
}

#[test]
fn text_is_readable_on_every_tint() {
    for t in tints() {
        let p = Palette::from_tint(t);
        assert!(contrast(p.ink, p.bg) >= 12.0, "ink on bg for {t:?}");
        assert!(
            contrast(p.ink, p.surface) >= 10.0,
            "ink on surface for {t:?}"
        );
        assert!(contrast(p.muted, p.bg) >= 4.5, "muted on bg for {t:?}");
        assert!(contrast(p.accent, p.bg) >= 4.5, "accent on bg for {t:?}");
        assert!(
            contrast(p.on_accent, p.accent) >= 4.5,
            "glyph on accent for {t:?}"
        );
        assert!(
            contrast(p.warn, p.surface) >= 4.5,
            "warn on surface for {t:?}"
        );
    }
}

#[test]
fn the_background_stays_dark() {
    for t in tints() {
        assert!(Palette::from_tint(t).bg.luminance() < 0.02, "{t:?}");
    }
}

#[test]
fn a_blue_cover_gives_a_blue_background() {
    let p = Palette::from_tint(Some(Tint {
        hue: 240.0,
        saturation: 0.9,
        second_hue: Some(300.0),
    }));
    assert!(p.bg.2 > p.bg.0 && p.bg.2 > p.bg.1);
}

#[test]
fn the_gradient_end_is_readable_and_dark_too() {
    for t in tints() {
        let p = Palette::from_tint(t);
        assert!(p.bg_end.luminance() < 0.05, "{t:?}");
        assert!(contrast(p.ink, p.bg_end) >= 10.0, "ink on end for {t:?}");
        assert!(contrast(p.muted, p.bg_end) >= 4.5, "muted on end for {t:?}");
        assert!(
            contrast(p.accent, p.bg_end) >= 4.5,
            "accent on end for {t:?}"
        );
    }
}

#[test]
fn the_gradient_ends_in_the_covers_second_colour() {
    let p = Palette::from_tint(Some(Tint {
        hue: 0.0,
        saturation: 0.9,
        second_hue: Some(240.0),
    }));
    assert!(p.bg.0 > p.bg.2, "start is red");
    assert!(p.bg_end.2 > p.bg_end.0, "end is blue");
}

#[test]
fn without_a_second_colour_the_end_still_differs_from_the_start() {
    let p = Palette::from_tint(Some(Tint {
        hue: 100.0,
        saturation: 0.9,
        second_hue: None,
    }));
    assert_ne!(p.bg, p.bg_end);
}

#[test]
fn hex_packs_the_channels() {
    assert_eq!(Rgb(0x12, 0x34, 0x56).hex(), 0x123456);
}
