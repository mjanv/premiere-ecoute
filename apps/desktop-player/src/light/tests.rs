use super::*;
use crate::remote_status::Exchange;
use std::time::Duration;

fn status(link: Link, sent_ago: Option<u64>, now: Instant) -> RemoteStatus {
    RemoteStatus {
        link,
        session: None,
        exchange: Exchange {
            last_snapshot_at: sent_ago.and_then(|s| now.checked_sub(Duration::from_secs(s))),
            ..Exchange::default()
        },
    }
}

fn spotify(running: bool) -> Snapshot {
    Snapshot {
        running,
        ..Snapshot::default()
    }
}

fn now() -> Instant {
    Instant::now() + Duration::from_secs(3600)
}

#[test]
fn linked_and_sending_with_spotify_running_is_green() {
    let now = now();
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Connected, Some(1), now), now),
        Light::Green
    );
}

#[test]
fn linked_without_spotify_is_amber() {
    let now = now();
    assert_eq!(
        Light::of(&spotify(false), &status(Link::Connected, Some(1), now), now),
        Light::Amber
    );
}

#[test]
fn linked_but_nothing_sent_for_a_while_is_amber() {
    // The backend gives up on a silent player after 5 s and falls back to polling Spotify.
    let now = now();
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Connected, Some(6), now), now),
        Light::Amber
    );
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Connected, Some(5), now), now),
        Light::Green
    );
}

#[test]
fn linked_but_nothing_sent_yet_is_amber() {
    let now = now();
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Connected, None, now), now),
        Light::Amber
    );
}

#[test]
fn a_link_on_its_way_or_retrying_is_amber() {
    let now = now();
    for link in [
        Link::SigningIn,
        Link::Connecting,
        Link::Offline {
            retry_in: Duration::from_secs(12),
        },
    ] {
        assert_eq!(
            Light::of(&spotify(true), &status(link.clone(), None, now), now),
            Light::Amber,
            "{link:?}"
        );
    }
}

#[test]
fn a_rejected_login_or_a_failure_is_red() {
    let now = now();
    for link in [Link::Unauthorized, Link::Failed("protocol".into())] {
        assert_eq!(
            Light::of(&spotify(true), &status(link.clone(), None, now), now),
            Light::Red,
            "{link:?}"
        );
    }
}

#[test]
fn an_unusable_player_is_red_whatever_the_link() {
    let now = now();
    let broken = Snapshot::failed("no media session");
    for link in [Link::Connected, Link::Disabled] {
        assert_eq!(
            Light::of(&broken, &status(link.clone(), Some(1), now), now),
            Light::Red,
            "{link:?}"
        );
    }
}

#[test]
fn local_only_is_grey() {
    let now = now();
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Disabled, None, now), now),
        Light::Grey
    );
}

#[test]
fn playing_or_paused_does_not_change_the_light() {
    let now = now();
    let paused = Snapshot {
        running: true,
        playback: crate::player::Playback::Paused,
        ..Snapshot::default()
    };
    let playing = Snapshot {
        playback: crate::player::Playback::Playing,
        ..paused.clone()
    };
    let linked = status(Link::Connected, Some(1), now);
    assert_eq!(
        Light::of(&paused, &linked, now),
        Light::of(&playing, &linked, now)
    );
}

#[test]
fn every_light_has_its_own_colour_and_a_description() {
    let all = [Light::Green, Light::Amber, Light::Red, Light::Grey];
    for (i, a) in all.iter().enumerate() {
        assert!(!a.description().is_empty());
        for b in &all[i + 1..] {
            assert_ne!(a.rgb(), b.rgb());
            assert_ne!(a.description(), b.description());
        }
    }
}
