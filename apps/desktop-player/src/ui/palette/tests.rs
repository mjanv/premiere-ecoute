use super::*;

fn tints() -> impl Iterator<Item = Option<Tint>> {
    let chromatic = (0..360).step_by(15).flat_map(|h| {
        [0.3, 0.7, 1.0].map(|s| Some(Tint { hue: h as f32, saturation: s }))
    });
    chromatic.chain([None, Some(Tint { hue: 0.0, saturation: 0.0 })])
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
        assert!(contrast(p.ink, p.surface) >= 10.0, "ink on surface for {t:?}");
        assert!(contrast(p.muted, p.bg) >= 4.5, "muted on bg for {t:?}");
        assert!(contrast(p.accent, p.bg) >= 4.5, "accent on bg for {t:?}");
        assert!(contrast(p.on_accent, p.accent) >= 4.5, "glyph on accent for {t:?}");
        assert!(contrast(p.warn, p.surface) >= 4.5, "warn on surface for {t:?}");
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
    let p = Palette::from_tint(Some(Tint { hue: 240.0, saturation: 0.9 }));
    assert!(p.bg.2 > p.bg.0 && p.bg.2 > p.bg.1);
}

#[test]
fn hex_packs_the_channels() {
    assert_eq!(Rgb(0x12, 0x34, 0x56).hex(), 0x123456);
}
