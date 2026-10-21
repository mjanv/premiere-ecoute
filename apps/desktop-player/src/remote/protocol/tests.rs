use super::*;

const ID: &str = "6rqhFgbbKwnb9MLmUQDhG6";

fn parse(frame: &str) -> Inbound {
    interpret(&decode_frame(frame).unwrap())
}

fn cmd(payload: Value) -> Inbound {
    interpret(&Frame {
        join_ref: None,
        msg_ref: None,
        topic: TOPIC.into(),
        event: "command".into(),
        payload,
    })
}

#[test]
fn frames_roundtrip_and_refs_may_be_null() {
    let text = r#"[null,"7","phoenix","heartbeat",{}]"#;
    let f = decode_frame(text).unwrap();
    assert_eq!(f.join_ref, None);
    assert_eq!(f.msg_ref.as_deref(), Some("7"));
    assert_eq!(decode_frame(&encode_frame(&f)).unwrap(), f);
}

#[test]
fn malformed_frames_are_errors_not_panics() {
    for bad in [
        "",
        "nope",
        "{}",
        "[]",
        r#"[1,2,3,4]"#,
        r#"[1,"1","t","e",{}]"#,
        r#"[null,"1",5,"e",{}]"#,
    ] {
        assert!(decode_frame(bad).is_err(), "{bad}");
    }
}

#[test]
fn join_matches_the_guide() {
    let f = decode_frame(&join("1", "sess-1", "0.1.0")).unwrap();
    assert_eq!(
        (f.topic.as_str(), f.event.as_str()),
        ("desktop:me", "phx_join")
    );
    assert_eq!(f.join_ref.as_deref(), Some("1"));
    assert_eq!(
        f.payload,
        json!({"proto": 1, "app_version": "0.1.0", "session_id": "sess-1"})
    );
}

#[test]
fn heartbeat_is_on_the_phoenix_topic_without_a_join_ref() {
    let f = decode_frame(&heartbeat(9)).unwrap();
    assert_eq!(
        (f.topic.as_str(), f.event.as_str(), f.join_ref),
        ("phoenix", "heartbeat", None)
    );
}

#[test]
fn snapshot_has_every_required_key() {
    let s = Snapshot {
        running: true,
        playback: Playback::Playing,
        uri: Some(format!("spotify:track:{ID}")),
        title: "T".into(),
        artist: "A".into(),
        album: "B".into(),
        position: Duration::from_millis(12_345),
        length: Duration::from_millis(215_000),
        volume: Some(0.5),
        ..Snapshot::default()
    };
    let f = decode_frame(&snapshot("1", 42, 7, &s)).unwrap();
    assert_eq!(f.event, "snapshot");
    assert_eq!(f.payload["seq"], 7);
    let p = &f.payload["snapshot"];
    assert_eq!(p["running"], true);
    assert_eq!(p["playback"], "playing");
    assert_eq!(p["uri"], format!("spotify:track:{ID}"));
    assert_eq!(
        (
            p["title"].as_str(),
            p["artist"].as_str(),
            p["album"].as_str()
        ),
        (Some("T"), Some("A"), Some("B"))
    );
    assert_eq!(
        (p["position_ms"].as_u64(), p["length_ms"].as_u64()),
        (Some(12_345), Some(215_000))
    );
    assert_eq!(p["volume"], 0.5);
}

#[test]
fn snapshot_says_not_running_with_no_uri_and_a_null_volume() {
    let s = Snapshot {
        uri: Some("spotify:local:x".into()),
        ..Snapshot::default()
    };
    let p = decode_frame(&snapshot("1", 2, 1, &s)).unwrap().payload["snapshot"].clone();
    assert_eq!(p["running"], false);
    assert_eq!(p["uri"], Value::Null);
    assert_eq!(p["volume"], Value::Null);
    assert_eq!(p["playback"], "stopped");
}

#[test]
fn snapshot_carries_the_album_position_and_modes() {
    let s = Snapshot {
        running: true,
        album_artist: "AA".into(),
        track_number: Some(3),
        album_track_count: Some(12),
        genres: vec!["Rock".into(), "Pop".into()],
        shuffle: Some(true),
        repeat: Some(Repeat::List),
        ..Snapshot::default()
    };
    let p = decode_frame(&snapshot("1", 2, 1, &s)).unwrap().payload["snapshot"].clone();
    assert_eq!(p["album_artist"], "AA");
    assert_eq!(p["track_number"], 3);
    assert_eq!(p["album_track_count"], 12);
    assert_eq!(p["genres"], json!(["Rock", "Pop"]));
    assert_eq!(p["shuffle"], true);
    assert_eq!(p["repeat"], "list");
}

#[test]
fn unknown_album_position_and_modes_are_null() {
    let s = Snapshot {
        running: true,
        ..Snapshot::default()
    };
    let p = decode_frame(&snapshot("1", 2, 1, &s)).unwrap().payload["snapshot"].clone();
    assert_eq!(p["track_number"], Value::Null);
    assert_eq!(p["album_track_count"], Value::Null);
    assert_eq!(p["shuffle"], Value::Null);
    assert_eq!(p["repeat"], Value::Null);
    assert_eq!(p["genres"], json!([]));
}

#[test]
fn repeat_modes_have_wire_names() {
    assert_eq!(Repeat::None.wire(), "none");
    assert_eq!(Repeat::Track.wire(), "track");
    assert_eq!(Repeat::List.wire(), "list");
}

#[test]
fn snapshot_sends_at_most_ten_genres_cut_to_512_characters() {
    let s = Snapshot {
        running: true,
        genres: vec!["é".repeat(600); 12],
        ..Snapshot::default()
    };
    let p = decode_frame(&snapshot("1", 2, 1, &s)).unwrap().payload["snapshot"].clone();
    let genres = p["genres"].as_array().unwrap();
    assert_eq!(genres.len(), 10);
    assert_eq!(genres[0].as_str().unwrap().chars().count(), 512);
}

#[test]
fn snapshot_text_is_cut_to_512_characters() {
    let s = Snapshot {
        running: true,
        title: "é".repeat(600),
        ..Snapshot::default()
    };
    let p = decode_frame(&snapshot("1", 2, 1, &s)).unwrap().payload["snapshot"].clone();
    assert_eq!(p["title"].as_str().unwrap().chars().count(), 512);
}

#[test]
fn ack_carries_the_status_and_an_optional_error() {
    let ok = decode_frame(&ack("1", 3, "c1", Outcome::Ok, None))
        .unwrap()
        .payload;
    assert_eq!(ok, json!({"command_id": "c1", "status": "ok"}));
    let bad = decode_frame(&ack("1", 4, "c2", Outcome::Rejected, Some("nope")))
        .unwrap()
        .payload;
    assert_eq!(
        bad,
        json!({"command_id": "c2", "status": "rejected", "error": "nope"})
    );
    let names: Vec<_> = [
        Outcome::Ok,
        Outcome::Error,
        Outcome::Rejected,
        Outcome::Expired,
        Outcome::Duplicate,
    ]
    .map(Outcome::wire)
    .to_vec();
    assert_eq!(names, ["ok", "error", "rejected", "expired", "duplicate"]);
}

#[test]
fn join_replies_are_understood() {
    let ok = r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":1000}}]"#;
    assert_eq!(
        parse(ok),
        Inbound::JoinOk {
            snapshot_interval: Duration::from_secs(1)
        }
    );
    let slow = r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":999999}}]"#;
    assert_eq!(
        parse(slow),
        Inbound::JoinOk {
            snapshot_interval: Duration::from_secs(30)
        }
    );
    let no = r#"["1","1","desktop:me","phx_reply",{"status":"error","response":{"reason":"unsupported_protocol"}}]"#;
    assert_eq!(
        parse(no),
        Inbound::JoinRefused {
            reason: "unsupported_protocol".into()
        }
    );
    let hb = r#"[null,"2","phoenix","phx_reply",{"status":"ok","response":{}}]"#;
    assert_eq!(parse(hb), Inbound::HeartbeatReply);
}

#[test]
fn every_command_type_in_the_guide_is_accepted() {
    let uri = format!("spotify:track:{ID}");
    let r = |t: &str, args: Value| match cmd(
        json!({"id": "c1", "type": t, "args": args, "ttl_ms": 10000}),
    ) {
        Inbound::Command(Ok(c)) => c,
        other => panic!("{t}: {other:?}"),
    };
    assert_eq!(
        r("play_uri", json!({"uri": uri})).command,
        Command::PlayUri(uri.clone())
    );
    assert_eq!(
        r("toggle_play_pause", json!({})).command,
        Command::TogglePlayPause
    );
    assert_eq!(r("next", json!({})).command, Command::Next);
    assert_eq!(r("previous", json!({})).command, Command::Previous);
    assert_eq!(
        r("set_volume", json!({"volume": 0.25})).command,
        Command::SetVolume(0.25)
    );
    assert_eq!(r("next", json!({})).ttl, Duration::from_secs(10));
    assert_eq!(r("next", json!({})).name, "next");
}

#[test]
fn invalid_commands_are_rejected_with_their_id() {
    let uri_ok = format!("spotify:track:{ID}");
    let cases = [
        json!({"id": "c1", "type": "format_disk", "args": {}}),
        json!({"id": "c1", "args": {}}),
        json!({"id": "c1", "type": "set_volume", "args": {"volume": 1.5}}),
        json!({"id": "c1", "type": "set_volume", "args": {"volume": -0.1}}),
        json!({"id": "c1", "type": "set_volume", "args": {"volume": "loud"}}),
        json!({"id": "c1", "type": "set_volume", "args": {}}),
        json!({"id": "c1", "type": "play_uri", "args": {"uri": "spotify:track:short"}}),
        json!({"id": "c1", "type": "play_uri", "args": {"uri": "spotify:album:6rqhFgbbKwnb9MLmUQDhG6"}}),
        json!({"id": "c1", "type": "play_uri", "args": {"uri": format!("https://open.spotify.com/track/{ID}")}}),
        json!({"id": "c1", "type": "play_uri", "args": {"uri": format!("{uri_ok}?x=1")}}),
        json!({"id": "c1", "type": "play_uri", "args": {}}),
    ];
    for c in cases {
        match cmd(c.clone()) {
            Inbound::Command(Err(r)) => assert_eq!(r.id.as_deref(), Some("c1"), "{c}"),
            other => panic!("{c}: {other:?}"),
        }
    }
}

#[test]
fn a_command_without_an_id_is_rejected_without_one() {
    assert!(matches!(
        cmd(json!({"type": "next", "args": {}})),
        Inbound::Command(Err(Rejection { id: None, .. }))
    ));
    assert!(matches!(
        cmd(json!({"id": "", "type": "next"})),
        Inbound::Command(Err(Rejection { id: None, .. }))
    ));
}

#[test]
fn ttl_defaults_and_is_capped() {
    let ttl = |p: Value| match cmd(p) {
        Inbound::Command(Ok(c)) => c.ttl,
        other => panic!("{other:?}"),
    };
    assert_eq!(
        ttl(json!({"id": "c", "type": "next"})),
        Duration::from_secs(10)
    );
    assert_eq!(
        ttl(json!({"id": "c", "type": "next", "ttl_ms": 3000})),
        Duration::from_secs(3)
    );
    assert_eq!(
        ttl(json!({"id": "c", "type": "next", "ttl_ms": 9_999_999})),
        Duration::from_secs(60)
    );
}

#[test]
fn disconnect_reasons_and_unknown_events() {
    let d = |r: &str| {
        parse(&format!(
            r#"["1",null,"desktop:me","disconnect",{{"reason":"{r}"}}]"#
        ))
    };
    assert_eq!(d("replaced"), Inbound::Disconnect(Disconnect::Replaced));
    assert_eq!(d("revoked"), Inbound::Disconnect(Disconnect::Revoked));
    assert_eq!(
        d("other"),
        Inbound::Disconnect(Disconnect::Other("other".into()))
    );
    assert_eq!(
        parse(r#"["1",null,"desktop:me","config",{"snapshot_interval_ms":2000}]"#),
        Inbound::Ignored
    );
    assert_eq!(
        parse(r#"["1",null,"desktop:me","mystery",{}]"#),
        Inbound::Ignored
    );
    assert_eq!(
        parse(r#"["1",null,"desktop:me","phx_close",{}]"#),
        Inbound::ChannelEnded
    );
    assert_eq!(
        parse(r#"["1",null,"desktop:me","phx_error",{}]"#),
        Inbound::ChannelEnded
    );
}

fn session_event(payload: Value) -> Inbound {
    interpret(&Frame {
        join_ref: None,
        msg_ref: None,
        topic: TOPIC.into(),
        event: "session".into(),
        payload,
    })
}

#[test]
fn a_running_session_is_read_with_its_position() {
    let inbound = session_event(json!({
        "state": "active", "source": "album", "name": "Plantation Lullabies",
        "track_number": 4, "track_count": 10
    }));
    assert_eq!(
        inbound,
        Inbound::Session(SessionInfo {
            state: SessionState::Active,
            source: Some("album".into()),
            name: Some("Plantation Lullabies".into()),
            track_number: Some(4),
            track_count: Some(10),
        })
    );
}

#[test]
fn no_session_and_a_prepared_one_are_read() {
    let none = session_event(json!({"state": "none", "source": null, "name": null,
        "track_number": null, "track_count": null}));
    assert!(matches!(
        none,
        Inbound::Session(SessionInfo {
            state: SessionState::None,
            source: None,
            name: None,
            ..
        })
    ));
    let prepared = session_event(json!({"state": "preparing", "source": "playlist"}));
    assert!(matches!(
        prepared,
        Inbound::Session(SessionInfo {
            state: SessionState::Preparing,
            track_number: None,
            ..
        })
    ));
}

#[test]
fn a_session_event_with_an_unknown_state_or_no_state_is_ignored() {
    assert_eq!(
        session_event(json!({"state": "exploding"})),
        Inbound::Ignored
    );
    assert_eq!(session_event(json!({"source": "album"})), Inbound::Ignored);
    assert_eq!(session_event(json!("nope")), Inbound::Ignored);
}

#[test]
fn session_numbers_that_make_no_sense_are_dropped_and_the_name_is_cut() {
    let Inbound::Session(info) = session_event(json!({
        "state": "active", "name": "é".repeat(600), "track_number": 0, "track_count": -3
    })) else {
        panic!("a session");
    };
    assert_eq!((info.track_number, info.track_count), (None, None));
    assert_eq!(info.name.unwrap().chars().count(), 512);
}

#[test]
fn a_session_event_on_another_topic_is_ignored() {
    let inbound = interpret(&Frame {
        join_ref: None,
        msg_ref: None,
        topic: "desktop:other".into(),
        event: "session".into(),
        payload: json!({"state": "active"}),
    });
    assert_eq!(inbound, Inbound::Ignored);
}

#[test]
fn a_track_number_with_play_uri_is_carried_to_the_player() {
    let uri = format!("spotify:track:{ID}");
    let command = |args: Value| match cmd(
        json!({"id": "c1", "type": "play_uri", "args": args, "ttl_ms": 10000}),
    ) {
        Inbound::Command(Ok(c)) => c.command,
        other => panic!("{other:?}"),
    };
    assert_eq!(
        command(json!({"uri": uri, "track_number": 4})),
        Command::PlayTrack {
            uri: uri.clone(),
            number: Some(4),
            duration: None
        }
    );
    // A number that makes no sense is ignored: the command still plays, only unchecked.
    for bad in [
        json!(0),
        json!(-1),
        json!("4"),
        json!(1000),
        json!(4.5),
        Value::Null,
    ] {
        assert_eq!(
            command(json!({"uri": uri, "track_number": bad})),
            Command::PlayUri(uri.clone()),
            "{bad}"
        );
    }
}

#[test]
fn the_exact_length_with_play_uri_is_carried_to_the_player() {
    let uri = format!("spotify:track:{ID}");
    let command = |args: Value| match cmd(
        json!({"id": "c1", "type": "play_uri", "args": args, "ttl_ms": 10000}),
    ) {
        Inbound::Command(Ok(c)) => c.command,
        other => panic!("{other:?}"),
    };
    assert_eq!(
        command(json!({"uri": uri, "track_number": 4, "duration_ms": 194_087})),
        Command::PlayTrack {
            uri: uri.clone(),
            number: Some(4),
            duration: Some(Duration::from_millis(194_087))
        }
    );
    // A single or a playlist track has a length but no number.
    assert_eq!(
        command(json!({"uri": uri, "duration_ms": 210_000})),
        Command::PlayTrack {
            uri: uri.clone(),
            number: None,
            duration: Some(Duration::from_secs(210))
        }
    );
    // A length that makes no sense is ignored: the track still plays, only paused a second early.
    for bad in [
        json!(0),
        json!(-1),
        json!("200"),
        json!(100.5),
        json!(86_400_000),
        Value::Null,
    ] {
        assert_eq!(
            command(json!({"uri": uri, "duration_ms": bad})),
            Command::PlayUri(uri.clone()),
            "{bad}"
        );
    }
}

#[test]
fn a_reply_to_a_snapshot_means_the_server_heard_it() {
    // The join reply carries the join's own reference; any other reply on the topic is a reply to
    // something the player pushed after it.
    let heard = r#"["1","5","desktop:me","phx_reply",{"status":"ok","response":{}}]"#;
    assert_eq!(parse(heard), Inbound::Heard);
    let refused =
        r#"["1","5","desktop:me","phx_reply",{"status":"error","response":{"reason":"x"}}]"#;
    assert_eq!(parse(refused), Inbound::Ignored);
}

#[test]
fn the_join_reply_is_still_the_join_reply() {
    let join = r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":1000}}]"#;
    assert!(matches!(parse(join), Inbound::JoinOk { .. }));
}
