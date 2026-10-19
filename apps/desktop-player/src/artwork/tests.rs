use super::*;

fn solid(rgb: [u8; 3], n: usize) -> Vec<u8> {
    (0..n).flat_map(|_| [rgb[0], rgb[1], rgb[2], 255]).collect()
}

fn near(hue: f32, want: f32) -> bool {
    let d = (hue - want).abs();
    d.min(360.0 - d) < 6.0
}

#[test]
fn sniff_recognises_png_and_jpeg_only() {
    assert_eq!(sniff(&[0x89, b'P', b'N', b'G', 1, 2]), Some(Format::Png));
    assert_eq!(sniff(&[0xFF, 0xD8, 0xFF, 0xE0]), Some(Format::Jpeg));
    assert_eq!(sniff(b"GIF89a"), None);
    assert_eq!(sniff(&[]), None);
}

#[test]
fn solid_colours_give_their_hue() {
    assert!(near(tint_from_rgba(&solid([255, 0, 0], 100)).hue, 0.0));
    assert!(near(tint_from_rgba(&solid([0, 0, 255], 100)).hue, 240.0));
    assert!(near(tint_from_rgba(&solid([0, 255, 0], 100)).hue, 120.0));
    assert!(tint_from_rgba(&solid([255, 0, 0], 100)).saturation > 0.9);
}

#[test]
fn the_larger_coloured_area_wins() {
    let mut px = solid([0, 200, 0], 70);
    px.extend(solid([200, 0, 0], 30));
    assert!(near(tint_from_rgba(&px).hue, 120.0));
}

#[test]
fn dark_and_grey_pixels_are_ignored() {
    let mut px = solid([12, 0, 0], 90);
    px.extend(solid([128, 128, 128], 90));
    px.extend(solid([255, 255, 0], 20));
    assert!(near(tint_from_rgba(&px).hue, 60.0));
}

#[test]
fn grey_cover_has_no_saturation() {
    let px = solid([120, 120, 120], 100);
    assert_eq!(tint_from_rgba(&px).saturation, 0.0);
    assert_eq!(tint_from_rgba(&[]).saturation, 0.0);
}

#[test]
fn from_bytes_rejects_garbage_and_decodes_a_real_png() {
    assert!(Artwork::from_bytes(vec![1, 2, 3]).is_none());
    assert!(Artwork::from_bytes(vec![0x89, b'P', b'N', b'G', 0, 0]).is_none());

    let mut png = Vec::new();
    let img = image::RgbaImage::from_pixel(8, 8, image::Rgba([0, 0, 255, 255]));
    img.write_to(&mut std::io::Cursor::new(&mut png), image::ImageFormat::Png)
        .unwrap();
    let art = Artwork::from_bytes(png).expect("valid png");
    assert!(near(art.tint.hue, 240.0));
}
