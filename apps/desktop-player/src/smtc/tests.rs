use super::*;

#[test]
fn a_refused_command_is_an_error() {
    assert_eq!(accepted(true), Ok(()));
    assert!(accepted(false).is_err());
}

#[test]
fn only_spotify_sessions_are_picked() {
    assert!(is_spotify_app("Spotify.exe"));
    assert!(is_spotify_app(
        "SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify"
    ));
    assert!(is_spotify_app("spotify"));
    assert!(!is_spotify_app("Chrome"));
    assert!(!is_spotify_app(""));
}

#[test]
fn smtc_statuses_map_to_the_three_playback_states() {
    assert_eq!(playback_from(Status::Playing), Playback::Playing);
    assert_eq!(playback_from(Status::Paused), Playback::Paused);
    assert_eq!(playback_from(Status::Stopped), Playback::Stopped);
    assert_eq!(playback_from(Status::Changing), Playback::Stopped);
    assert_eq!(playback_from(Status::Closed), Playback::Stopped);
}

#[test]
fn timeline_ticks_are_hundred_nanoseconds_and_never_negative() {
    assert_eq!(
        ticks(TimeSpan {
            Duration: 10_000_000
        }),
        Duration::from_secs(1)
    );
    assert_eq!(ticks(TimeSpan { Duration: 5 }), Duration::from_nanos(500));
    assert_eq!(ticks(TimeSpan { Duration: -42 }), Duration::ZERO);
}

#[test]
fn the_time_since_the_last_timeline_update_counts_from_1601() {
    let unix = |s: u64| UNIX_EPOCH + Duration::from_secs(s);
    let updated = |unix_s: i64| DateTime {
        UniversalTime: (unix_s + 11_644_473_600) * 10_000_000,
    };
    assert_eq!(
        since_update(updated(1_000), unix(1_003)),
        Duration::from_secs(3)
    );
    assert_eq!(since_update(updated(1_000), unix(1_000)), Duration::ZERO);
}

#[test]
fn an_update_in_the_future_or_unset_never_underflows() {
    let now = UNIX_EPOCH + Duration::from_secs(1_000);
    let future = DateTime {
        UniversalTime: (2_000 + 11_644_473_600) * 10_000_000,
    };
    assert_eq!(since_update(future, now), Duration::ZERO);
    // Unset (0) or negative reads as the year 1601: a huge elapsed time, which `current_position` caps.
    assert!(since_update(DateTime { UniversalTime: -1 }, now) > Duration::from_secs(1 << 33));
}
