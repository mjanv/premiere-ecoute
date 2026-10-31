use super::*;

fn secs(s: u64) -> Duration {
    Duration::from_secs(s)
}

#[test]
fn a_three_and_a_half_minute_track_ticks_every_five_seconds() {
    assert_eq!(tick_step(secs(210)), secs(5));
    let t = ticks(secs(210));
    assert_eq!(t.len(), 43);
    assert_eq!(t[0].fraction, 0.0);
    assert!(t.iter().all(|t| (0.0..=1.0).contains(&t.fraction)));
}

#[test]
fn major_ticks_fall_on_minutes_and_carry_the_minute_number() {
    let t = ticks(secs(210));
    let majors: Vec<_> = t.iter().filter(|t| t.kind == TickKind::Major).collect();
    assert_eq!(majors.len(), 4); // 0:00, 1:00, 2:00, 3:00
    let labels: Vec<_> = t.iter().filter_map(|t| t.label).collect();
    assert_eq!(labels, [1, 2, 3]);
}

#[test]
fn long_tracks_widen_the_step_and_label_every_fifth_minute() {
    assert_eq!(tick_step(secs(1200)), secs(15));
    let labels: Vec<_> = ticks(secs(1200)).iter().filter_map(|t| t.label).collect();
    assert_eq!(labels, [5, 10, 15, 20]);
}

#[test]
fn the_ruler_never_exceeds_the_tick_budget() {
    for len in [1, 30, 210, 600, 1200, 3600, 7200, 36_000] {
        assert!(
            ticks(secs(len)).len() as u64 <= MAX_TICKS + 1,
            "length {len}"
        );
    }
}

#[test]
fn empty_for_unknown_length() {
    assert!(ticks(Duration::ZERO).is_empty());
}
