use super::*;
use crate::player::Playback;
use crate::remote_status::{CommandLog, Exchange, Outcome, SessionInfo, SessionState};
use std::time::Duration;

fn now() -> Instant {
    Instant::now() + Duration::from_secs(3600)
}

fn remote(
    link: Link,
    sent_ago: Option<u64>,
    command: Option<(Outcome, u64)>,
    now: Instant,
) -> RemoteStatus {
    RemoteStatus {
        link,
        session: None,
        heard_at: None,
        exchange: Exchange {
            last_snapshot_at: sent_ago.and_then(|s| now.checked_sub(Duration::from_secs(s))),
            last_command: command.map(|(outcome, ago)| CommandLog {
                name: "next".into(),
                outcome,
                at: now - Duration::from_secs(ago),
            }),
            ..Exchange::default()
        },
    }
}

fn spotify(running: bool, playback: Playback) -> Snapshot {
    Snapshot {
        running,
        playback,
        ..Snapshot::default()
    }
}

fn find<'a>(checks: &'a [Check], label: &str) -> &'a Check {
    checks.iter().find(|c| c.label == label).unwrap()
}

#[test]
fn the_checklist_has_its_rows_in_order() {
    let now = now();
    let checks = checks(
        &spotify(true, Playback::Playing),
        &remote(Link::Connected, Some(1), None, now),
        now,
    );
    let labels: Vec<_> = checks.iter().map(|c| c.label).collect();
    assert_eq!(labels, ["Server", "Spotify", "Data", "Commands"]);
}

#[test]
fn the_server_row_follows_the_link() {
    let now = now();
    let row = |link: Link| {
        let c = checks(
            &spotify(true, Playback::Playing),
            &remote(link, None, None, now),
            now,
        );
        let server = find(&c, "Server");
        (server.state, server.detail.clone())
    };
    assert_eq!(row(Link::Connected), (CheckState::Ok, "Linked".into()));
    assert_eq!(
        row(Link::Connecting),
        (CheckState::Wait, "Connecting".into())
    );
    assert_eq!(
        row(Link::SigningIn),
        (CheckState::Wait, "Waiting for the browser".into())
    );
    assert_eq!(
        row(Link::Offline {
            retry_in: Duration::from_secs(12)
        }),
        (CheckState::Bad, "Offline, retry in 12 s".into())
    );
    assert_eq!(
        row(Link::Unauthorized),
        (CheckState::Bad, "Sign in again".into())
    );
    assert_eq!(
        row(Link::Failed("refused".into())),
        (CheckState::Bad, "Error: refused".into())
    );
    assert_eq!(row(Link::Disabled), (CheckState::Off, "Not linked".into()));
}

#[test]
fn the_spotify_row_says_what_to_do() {
    let now = now();
    let linked = remote(Link::Connected, Some(1), None, now);
    let row = |snap: Snapshot| {
        let c = checks(&snap, &linked, now);
        let spotify = find(&c, "Spotify");
        (spotify.state, spotify.detail.clone())
    };
    assert_eq!(
        row(spotify(false, Playback::Stopped)),
        (CheckState::Wait, "Not running. Open Spotify".into())
    );
    assert_eq!(
        row(spotify(true, Playback::Playing)),
        (CheckState::Ok, "Playing".into())
    );
    assert_eq!(
        row(spotify(true, Playback::Paused)),
        (CheckState::Ok, "Paused".into())
    );
    assert_eq!(
        row(Snapshot::failed("no media session")),
        (CheckState::Bad, "Can't read it: no media session".into())
    );
}

#[test]
fn the_data_row_proves_snapshots_are_leaving() {
    let now = now();
    let row = |sent: Option<u64>, link: Link| {
        let c = checks(
            &spotify(true, Playback::Playing),
            &remote(link, sent, None, now),
            now,
        );
        let data = find(&c, "Data");
        (data.state, data.detail.clone())
    };
    assert_eq!(
        row(Some(0), Link::Connected),
        (CheckState::Ok, "Sent now".into())
    );
    assert_eq!(
        row(Some(3), Link::Connected),
        (CheckState::Ok, "Sent 3s".into())
    );
    assert_eq!(
        row(Some(8), Link::Connected),
        (CheckState::Bad, "Nothing sent for 8s".into())
    );
    assert_eq!(
        row(None, Link::Connected),
        (CheckState::Wait, "Waiting for the first send".into())
    );
    assert_eq!(
        row(None, Link::Connecting),
        (CheckState::Off, "Waiting for the server".into())
    );
}

#[test]
fn the_commands_row_shows_the_last_answer_and_never_blocks_the_verdict() {
    let now = now();
    let row = |command: Option<(Outcome, u64)>| {
        let c = checks(
            &spotify(true, Playback::Playing),
            &remote(Link::Connected, Some(1), command, now),
            now,
        );
        let r = find(&c, "Commands");
        (r.state, r.detail.clone())
    };
    assert_eq!(row(None), (CheckState::Off, "None received yet".into()));
    assert_eq!(
        row(Some((Outcome::Ok, 18))),
        (CheckState::Ok, "next, ok 18s".into())
    );
    assert_eq!(
        row(Some((Outcome::Error, 4))),
        (CheckState::Bad, "next, failed 4s".into())
    );
    assert_eq!(row(Some((Outcome::Rejected, 4))).0, CheckState::Bad);
    assert_eq!(row(Some((Outcome::Expired, 4))).0, CheckState::Bad);
    assert_eq!(row(Some((Outcome::Duplicate, 4))).0, CheckState::Ok);
}

#[test]
fn the_verdict_names_the_state_and_the_first_thing_to_fix() {
    let now = now();
    let verdict = |snap: Snapshot, link: Link, sent: Option<u64>| {
        let r = remote(link, sent, None, now);
        let v = verdict(&snap, &r, now);
        (v.light, v.title, v.hint)
    };
    assert_eq!(
        verdict(spotify(true, Playback::Playing), Link::Connected, Some(1)),
        (Light::Green, "READY", "Linked and sending".into())
    );
    assert_eq!(
        verdict(spotify(false, Playback::Stopped), Link::Connected, Some(1)),
        (
            Light::Amber,
            "WAITING",
            "Spotify: not running. Open Spotify".into()
        )
    );
    assert_eq!(
        verdict(spotify(true, Playback::Playing), Link::Connected, Some(9)),
        (Light::Amber, "WAITING", "Data: nothing sent for 9s".into())
    );
    assert_eq!(
        verdict(spotify(true, Playback::Playing), Link::Unauthorized, None),
        (Light::Red, "ACTION NEEDED", "Server: sign in again".into())
    );
    assert_eq!(
        verdict(spotify(true, Playback::Playing), Link::Disabled, None),
        (Light::Grey, "LOCAL ONLY", "Not linked to a server".into())
    );
}

#[test]
fn green_means_every_link_row_is_ok_and_only_then() {
    let now = now();
    let links = [
        Link::Disabled,
        Link::SigningIn,
        Link::Connecting,
        Link::Connected,
        Link::Offline {
            retry_in: Duration::from_secs(5),
        },
        Link::Unauthorized,
        Link::Failed("x".into()),
    ];
    let snaps = [
        spotify(true, Playback::Playing),
        spotify(true, Playback::Paused),
        spotify(false, Playback::Stopped),
        Snapshot::failed("boom"),
    ];
    for link in &links {
        for snap in &snaps {
            for (sent, heard) in [
                (None, None),
                (Some(1), None),
                (Some(9), None),
                (Some(1), Some(1)),
                (Some(1), Some(9)),
            ] {
                let mut r = remote(link.clone(), sent, None, now);
                r.heard_at = heard.map(|s| now - Duration::from_secs(s));
                let rows = checks(snap, &r, now);
                let all_ok = ["Server", "Spotify", "Data"]
                    .iter()
                    .all(|l| find(&rows, l).state == CheckState::Ok);
                let green = Light::of(snap, &r, now) == Light::Green;
                assert_eq!(
                    green, all_ok,
                    "{link:?} {snap:?} sent {sent:?} heard {heard:?}"
                );
            }
        }
    }
}

fn view(session: Option<SessionInfo>, link: Link) -> SessionView {
    let now = now();
    let mut remote = remote(link, Some(1), None, now);
    remote.session = session;
    session_view(&remote)
}

fn info(
    state: SessionState,
    source: Option<&str>,
    name: Option<&str>,
    n: Option<u32>,
    of: Option<u32>,
) -> SessionInfo {
    SessionInfo {
        state,
        source: source.map(Into::into),
        name: name.map(Into::into),
        track_number: n,
        track_count: of,
    }
}

#[test]
fn a_running_session_shows_its_source_name_and_track() {
    let running = info(
        SessionState::Active,
        Some("album"),
        Some("Plantation Lullabies"),
        Some(4),
        Some(10),
    );
    let v = view(Some(running), Link::Connected);
    assert_eq!(v.state, CheckState::Ok);
    assert_eq!(v.headline, "RUNNING");
    assert_eq!(v.subtitle, "Album · Plantation Lullabies");
    assert_eq!(v.position.as_deref(), Some("4/10"));
}

#[test]
fn a_session_leaves_out_what_the_server_did_not_give() {
    let v = view(
        Some(info(
            SessionState::Active,
            Some("playlist"),
            Some("Mix"),
            None,
            Some(12),
        )),
        Link::Connected,
    );
    assert_eq!((v.subtitle.as_str(), v.position), ("Playlist · Mix", None));
    let v = view(
        Some(info(
            SessionState::Active,
            Some("album"),
            None,
            Some(2),
            None,
        )),
        Link::Connected,
    );
    assert_eq!(
        (v.subtitle.as_str(), v.position.as_deref()),
        ("Album", Some("2"))
    );
    let v = view(
        Some(info(SessionState::Active, None, None, None, None)),
        Link::Connected,
    );
    assert_eq!((v.subtitle.as_str(), v.position), ("", None));
}

#[test]
fn a_free_session_does_not_repeat_its_own_name() {
    let v = view(
        Some(info(
            SessionState::Active,
            Some("free"),
            Some("Free session"),
            None,
            None,
        )),
        Link::Connected,
    );
    assert_eq!(v.subtitle, "Free session");
    let v = view(
        Some(info(
            SessionState::Active,
            Some("free"),
            Some("Friday blind listen"),
            None,
            None,
        )),
        Link::Connected,
    );
    assert_eq!(v.subtitle, "Free session · Friday blind listen");
}

#[test]
fn every_source_has_a_readable_label() {
    for (source, label) in [
        ("album", "Album"),
        ("playlist", "Playlist"),
        ("track", "Track"),
        ("clip", "Clip"),
    ] {
        let v = view(
            Some(info(SessionState::Active, Some(source), None, None, None)),
            Link::Connected,
        );
        assert_eq!(v.subtitle, label);
    }
    let v = view(
        Some(info(
            SessionState::Active,
            Some("hologram"),
            Some("X"),
            None,
            None,
        )),
        Link::Connected,
    );
    assert_eq!(v.subtitle, "X");
}

#[test]
fn a_prepared_session_is_not_started_yet() {
    let v = view(
        Some(info(
            SessionState::Preparing,
            Some("album"),
            Some("Mix"),
            Some(1),
            Some(5),
        )),
        Link::Connected,
    );
    assert_eq!(
        (v.state, v.headline, v.subtitle.as_str()),
        (CheckState::Wait, "READY TO START", "Album · Mix")
    );
    // Nothing plays yet: no position.
    assert_eq!(v.position, None);
}

#[test]
fn no_session_says_so_and_where_to_start_one() {
    let v = view(
        Some(info(SessionState::None, None, None, None, None)),
        Link::Connected,
    );
    assert_eq!((v.state, v.headline), (CheckState::Off, "NO SESSION"));
    assert_eq!(v.subtitle, "Start one from the dashboard");
}

#[test]
fn before_the_server_answers_or_without_a_live_link_the_session_is_unknown() {
    for (session, link) in [
        (None, Link::Connected),
        (
            Some(info(
                SessionState::Active,
                Some("album"),
                Some("A"),
                Some(1),
                Some(2),
            )),
            Link::Offline {
                retry_in: Duration::from_secs(5),
            },
        ),
        (None, Link::Disabled),
    ] {
        let v = view(session, link);
        assert_eq!(
            (v.state, v.headline, v.subtitle.as_str()),
            (CheckState::Off, "UNKNOWN", "Waiting for the server")
        );
    }
}

#[test]
fn a_session_never_changes_the_verdict() {
    let now = now();
    for session in [
        None,
        Some(info(SessionState::None, None, None, None, None)),
        Some(info(
            SessionState::Preparing,
            Some("album"),
            Some("Mix"),
            None,
            None,
        )),
        Some(info(
            SessionState::Active,
            Some("album"),
            Some("Mix"),
            Some(1),
            Some(2),
        )),
    ] {
        let mut r = remote(Link::Connected, Some(1), None, now);
        r.session = session;
        let v = verdict(&spotify(true, Playback::Playing), &r, now);
        assert_eq!(v.light, Light::Green);
    }
}

fn with_heard(sent_ago: u64, heard_ago: Option<u64>) -> (CheckState, String) {
    let now = now();
    let mut r = remote(Link::Connected, Some(sent_ago), None, now);
    r.heard_at = heard_ago.map(|s| now - Duration::from_secs(s));
    let rows = checks(&spotify(true, Playback::Playing), &r, now);
    let data = find(&rows, "Data");
    (data.state, data.detail.clone())
}

#[test]
fn the_data_row_says_the_server_heard_when_it_replies() {
    assert_eq!(
        with_heard(0, Some(0)),
        (CheckState::Ok, "Sent now, heard now".into())
    );
    assert_eq!(
        with_heard(3, Some(2)),
        (CheckState::Ok, "Sent 3s, heard 2s".into())
    );
}

#[test]
fn a_server_that_stops_replying_while_the_player_sends_is_a_problem() {
    assert_eq!(
        with_heard(3, Some(9)),
        (CheckState::Bad, "Sent 3s, not heard for 9s".into())
    );
}

#[test]
fn a_server_that_never_replies_is_not_blamed() {
    // An older backend does not acknowledge snapshots: the row is what it was.
    assert_eq!(with_heard(3, None), (CheckState::Ok, "Sent 3s".into()));
}

#[test]
fn a_server_that_stopped_replying_makes_the_light_amber() {
    let now = now();
    let mut r = remote(Link::Connected, Some(1), None, now);
    r.heard_at = Some(now - Duration::from_secs(9));
    assert_eq!(
        Light::of(&spotify(true, Playback::Playing), &r, now),
        Light::Amber
    );
    r.heard_at = Some(now - Duration::from_secs(1));
    assert_eq!(
        Light::of(&spotify(true, Playback::Playing), &r, now),
        Light::Green
    );
}
