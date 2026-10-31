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

#[test]
fn smtc_counts_of_zero_or_less_mean_unknown() {
    assert_eq!(count(0), None);
    assert_eq!(count(-1), None);
    assert_eq!(count(7), Some(7));
}

#[test]
fn smtc_repeat_modes_map_to_ours() {
    assert_eq!(repeat_from(MediaPlaybackAutoRepeatMode::None), Repeat::None);
    assert_eq!(
        repeat_from(MediaPlaybackAutoRepeatMode::Track),
        Repeat::Track
    );
    assert_eq!(repeat_from(MediaPlaybackAutoRepeatMode::List), Repeat::List);
}

#[test]
fn a_track_line_shows_what_spotify_reported_and_what_it_left_out() {
    let full = Snapshot {
        title: "Song".into(),
        artist: "Artist".into(),
        album: "Album".into(),
        album_artist: "Album Artist".into(),
        track_number: Some(3),
        album_track_count: Some(12),
        genres: vec!["Rock".into(), "Pop".into()],
        shuffle: Some(false),
        repeat: Some(Repeat::List),
        length: Duration::from_secs(215),
        ..Snapshot::default()
    };
    assert_eq!(
        track_line(&full),
        r#"track "Song" by "Artist", album "Album" by "Album Artist", number 3/12, genres [Rock, Pop], shuffle false, repeat list, 215 s"#
    );
    let bare = Snapshot {
        title: "Song".into(),
        ..Snapshot::default()
    };
    assert_eq!(
        track_line(&bare),
        r#"track "Song" by "", album "" by "", number ?/?, genres [], shuffle ?, repeat ?, 0 s"#
    );
}

#[test]
fn a_volume_error_is_logged_when_it_appears_or_changes_not_at_every_look() {
    let mut last = None;
    assert_eq!(
        new_volume_error(&mut last, Some("no audio session".into())),
        Some("no audio session".to_string())
    );
    // The same error at the next look: nothing more to say.
    assert_eq!(
        new_volume_error(&mut last, Some("no audio session".into())),
        None
    );
    assert_eq!(
        new_volume_error(&mut last, Some("device lost".into())),
        Some("device lost".to_string())
    );
}

#[test]
fn a_volume_that_works_again_clears_the_error_so_a_later_one_is_logged() {
    let mut last = None;
    new_volume_error(&mut last, Some("x".into()));
    assert_eq!(new_volume_error(&mut last, None), None);
    assert_eq!(
        new_volume_error(&mut last, Some("x".into())),
        Some("x".to_string())
    );
}
