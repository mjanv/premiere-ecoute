use super::*;
use std::time::Duration;

fn status(link: Link) -> RemoteStatus {
    RemoteStatus {
        link,
        ..RemoteStatus::default()
    }
}

fn spotify(running: bool) -> Snapshot {
    Snapshot {
        running,
        ..Snapshot::default()
    }
}

#[test]
fn linked_with_spotify_running_is_green() {
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Connected)),
        Light::Green
    );
}

#[test]
fn linked_without_spotify_is_amber() {
    assert_eq!(
        Light::of(&spotify(false), &status(Link::Connected)),
        Light::Amber
    );
}

#[test]
fn a_link_on_its_way_or_retrying_is_amber() {
    for link in [
        Link::SigningIn,
        Link::Connecting,
        Link::Offline {
            retry_in: Duration::from_secs(12),
        },
    ] {
        assert_eq!(
            Light::of(&spotify(true), &status(link.clone())),
            Light::Amber,
            "{link:?}"
        );
    }
}

#[test]
fn a_rejected_login_or_a_failure_is_red() {
    for link in [Link::Unauthorized, Link::Failed("protocol".into())] {
        assert_eq!(
            Light::of(&spotify(true), &status(link.clone())),
            Light::Red,
            "{link:?}"
        );
    }
}

#[test]
fn an_unusable_player_is_red_whatever_the_link() {
    let broken = Snapshot::failed("no media session");
    for link in [Link::Connected, Link::Disabled] {
        assert_eq!(
            Light::of(&broken, &status(link.clone())),
            Light::Red,
            "{link:?}"
        );
    }
}

#[test]
fn local_only_is_grey() {
    assert_eq!(
        Light::of(&spotify(true), &status(Link::Disabled)),
        Light::Grey
    );
}

#[test]
fn playing_or_paused_does_not_change_the_light() {
    let paused = Snapshot {
        running: true,
        playback: crate::player::Playback::Paused,
        ..Snapshot::default()
    };
    let playing = Snapshot {
        playback: crate::player::Playback::Playing,
        ..paused.clone()
    };
    let linked = status(Link::Connected);
    assert_eq!(Light::of(&paused, &linked), Light::of(&playing, &linked));
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
