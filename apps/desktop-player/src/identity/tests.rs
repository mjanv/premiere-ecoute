use super::*;

fn id(title: &str) -> Identity {
    Identity {
        title: title.into(),
        artist: "Artist".into(),
        album: "Album".into(),
        seconds: 200,
    }
}

#[test]
fn the_synthetic_uri_encodes_every_part_and_has_no_stray_colons() {
    let i = Identity {
        title: "A:B C".into(),
        artist: "Sampha & Co".into(),
        album: "X".into(),
        seconds: 61,
    };
    assert_eq!(
        synthetic_uri(&i),
        "spotify:local:Sampha+%26+Co:X:A%3AB+C:61"
    );
}

#[test]
fn the_uri_is_stable_for_a_track_and_changes_with_the_track() {
    let (mut t, now) = (UriTracker::default(), Instant::now());
    let a = t.observe(id("One"), now).unwrap();
    assert_eq!(t.observe(id("One"), now), Some(a.clone()));
    assert_ne!(t.observe(id("Two"), now).unwrap(), a);
}

#[test]
fn a_commanded_uri_is_taken_by_the_next_track_change_and_kept() {
    let (mut t, now) = (UriTracker::default(), Instant::now());
    t.observe(id("Old"), now);
    t.commanded("spotify:track:abc".into(), now);
    assert_eq!(
        t.observe(id("Old"), now).unwrap(),
        synthetic_uri(&id("Old"))
    );
    assert_eq!(
        t.observe(id("New"), now).as_deref(),
        Some("spotify:track:abc")
    );
    assert_eq!(
        t.observe(id("New"), now).as_deref(),
        Some("spotify:track:abc")
    );
    // The commanded URI was used up: the next change is synthetic again.
    assert_eq!(
        t.observe(id("Next"), now).unwrap(),
        synthetic_uri(&id("Next"))
    );
}

#[test]
fn a_commanded_uri_that_never_caused_a_change_expires() {
    let (mut t, now) = (UriTracker::default(), Instant::now());
    t.observe(id("Same"), now);
    t.commanded("spotify:track:abc".into(), now);
    let later = now + PENDING_TTL + Duration::from_secs(1);
    assert_eq!(
        t.observe(id("Other"), later).unwrap(),
        synthetic_uri(&id("Other"))
    );
}

#[test]
fn no_title_means_no_uri_and_forget_starts_over() {
    let (mut t, now) = (UriTracker::default(), Instant::now());
    assert_eq!(t.observe(id(""), now), None);
    let a = t.observe(id("One"), now).unwrap();
    t.forget();
    t.commanded("spotify:track:abc".into(), now);
    assert_eq!(
        t.observe(id("One"), now).as_deref(),
        Some("spotify:track:abc")
    );
    assert_ne!(a, "spotify:track:abc");
}
