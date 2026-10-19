use super::*;

#[test]
fn the_delay_ceiling_doubles_up_to_a_minute() {
    let mut b = Backoff::default();
    let ceilings: Vec<_> = (0..9).map(|_| b.next_delay(1.0).as_secs()).collect();
    assert_eq!(ceilings, [1, 2, 4, 8, 16, 32, 60, 60, 60]);
}

#[test]
fn the_delay_is_random_below_the_ceiling_and_never_below_the_floor() {
    let mut b = Backoff::default();
    b.next_delay(1.0);
    b.next_delay(1.0);
    assert_eq!(b.next_delay(0.5), Duration::from_secs(2)); // ceiling 4 s, half of it
    assert_eq!(b.next_delay(0.0), FLOOR);
    assert!(b.next_delay(7.0) <= CAP);
}

#[test]
fn reset_starts_over() {
    let mut b = Backoff::default();
    for _ in 0..5 {
        b.next_delay(1.0);
    }
    b.reset();
    assert_eq!(b.next_delay(1.0), Duration::from_secs(1));
}

#[test]
fn seen_ids_remember_the_most_recent_ones_only() {
    let mut s = SeenIds::new(3);
    assert!(s.insert("a"));
    assert!(!s.insert("a"));
    s.insert("b");
    s.insert("c");
    s.insert("d"); // evicts a
    assert!(s.insert("a"));
    assert!(!s.insert("d"));
}
