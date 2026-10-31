use super::*;

#[test]
fn stereo_is_averaged_into_mono_and_scaled() {
    let mut out = Vec::new();
    mono_from_i16_stereo(&[16384, 16384, -32768, 0, 100], &mut out);
    assert_eq!(out, [0.5, -0.5]);
    mono_from_i16_stereo(&[], &mut out);
    assert_eq!(out.len(), 2);
}

#[test]
fn the_trace_has_the_requested_length_whatever_is_held() {
    let (mut s, now) = (Scope::default(), Instant::now());
    s.push(&[0.5, -0.5, 0.25], now);
    assert_eq!(s.trace(8, now).len(), 8);
    assert_eq!(s.trace(2, now).len(), 2);
    assert_eq!(s.trace(0, now), Vec::<f32>::new());
}

#[test]
fn each_point_keeps_the_biggest_swing_of_its_slice_with_its_sign() {
    let (mut s, now) = (Scope::default(), Instant::now());
    s.push(&[0.1, -0.8, 0.2, 0.3, 0.9, -0.1], now);
    // Two slices of three samples; the reference is the loudest sample, 0.9.
    let t = s.trace(2, now);
    assert!((t[0] - (-0.8 / 0.9)).abs() < 1e-6, "{t:?}");
    assert!((t[1] - 1.0).abs() < 1e-6, "{t:?}");
}

#[test]
fn the_window_is_bounded_and_keeps_the_newest_samples() {
    let (mut s, now) = (Scope::default(), Instant::now());
    s.push(&vec![0.1; WINDOW], now);
    s.push(&vec![0.9; WINDOW], now);
    assert_eq!(s.window.len(), WINDOW);
    assert!(s.trace(4, now).iter().all(|v| (*v - 1.0).abs() < 1e-6));
}

#[test]
fn nothing_playing_is_a_flat_line() {
    let (mut s, now) = (Scope::default(), Instant::now());
    assert_eq!(s.trace(5, now), [0.0; 5]);
    s.push(&[0.9, -0.9], now);
    assert!(s.is_live(now));
    let later = now + Duration::from_millis(400);
    assert!(!s.is_live(later));
    assert_eq!(s.trace(5, later), [0.0; 5]);
    assert!(!Scope::default().is_live(now));
}

#[test]
fn quiet_sound_fills_the_box_but_near_silence_does_not() {
    let now = Instant::now();
    let mut quiet = Scope::default();
    quiet.push(&[0.2, -0.2], now);
    assert!((quiet.trace(2, now)[0] - 1.0).abs() < 1e-6); // scaled to its own loudness

    let mut hush = Scope::default();
    hush.push(&[0.004, -0.004], now);
    assert!(hush.trace(2, now).iter().all(|v| v.abs() < 0.2));
}

#[test]
fn after_a_loud_passage_quiet_sound_reads_lower_then_recovers() {
    let now = Instant::now();
    let mut s = Scope::default();
    s.push(&vec![1.0; WINDOW], now);
    s.push(&vec![0.1; WINDOW], now); // the loud samples have left the window
    let right_after = s.trace(1, now)[0].abs();
    for _ in 0..2000 {
        s.push(&vec![0.1; WINDOW], now);
    }
    assert!(right_after < 0.2, "{right_after}");
    assert!(s.trace(1, now)[0].abs() > right_after);
}

#[test]
fn bad_values_never_escape_the_range() {
    let (mut s, now) = (Scope::default(), Instant::now());
    s.push(&[f32::NAN, f32::INFINITY, -7.0, 9.0, 0.3], now);
    let t = s.trace(6, now);
    assert!(t.iter().all(|v| (-1.0..=1.0).contains(v)), "{t:?}");
}
