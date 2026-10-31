use super::*;

const RING: [u8; 3] = [0x14, 0x14, 0x14];

fn px(pixels: &[u8], x: usize, y: usize) -> [u8; 4] {
    let i = (y * SIZE + x) * 4;
    [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]]
}

#[test]
fn the_dot_is_a_square_bitmap_of_four_bytes_per_pixel() {
    assert_eq!(dot_pixels([0, 200, 80]).len(), SIZE * SIZE * 4);
}

#[test]
fn the_centre_has_the_light_colour_fully_opaque() {
    // BGRA order, as Windows wants it.
    let c = SIZE / 2;
    assert_eq!(px(&dot_pixels([10, 200, 80]), c, c), [80, 200, 10, 255]);
}

#[test]
fn the_corners_are_transparent() {
    let p = dot_pixels([10, 200, 80]);
    for (x, y) in [(0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)] {
        assert_eq!(px(&p, x, y)[3], 0, "{x},{y}");
    }
}

#[test]
fn the_rim_is_dark_so_the_dot_reads_on_any_taskbar() {
    let p = dot_pixels([240, 240, 240]);
    let mid = SIZE / 2;
    let rim = (0..SIZE)
        .map(|x| px(&p, x, mid))
        .find(|px| px[3] == 255)
        .expect("an opaque pixel on the middle row");
    assert_eq!([rim[2], rim[1], rim[0]], RING);
}
