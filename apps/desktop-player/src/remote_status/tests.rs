use super::*;

#[test]
fn link_labels_say_what_to_do_or_what_is_happening() {
    assert_eq!(Link::Disabled.label(), "Local only");
    assert_eq!(Link::Connected.label(), "Server linked");
    assert_eq!(Link::SigningIn.label(), "Waiting for the browser");
    assert_eq!(
        Link::Offline {
            retry_in: Duration::from_secs(12)
        }
        .label(),
        "Server offline, retry in 12 s"
    );
    assert_eq!(
        Link::Offline {
            retry_in: Duration::ZERO
        }
        .label(),
        "Server offline, retry in 1 s"
    );
    assert_eq!(Link::Unauthorized.label(), "Server: sign in again");
    assert_eq!(Link::Failed("boom".into()).label(), "Server error: boom");
}

#[test]
fn only_a_live_link_is_good_and_problems_are_warnings() {
    assert_eq!(Link::Connected.tone(), Tone::Good);
    assert_eq!(Link::Disabled.tone(), Tone::Idle);
    assert_eq!(Link::Connecting.tone(), Tone::Idle);
    assert_eq!(Link::Unauthorized.tone(), Tone::Warn);
    assert_eq!(Link::Failed("x".into()).tone(), Tone::Warn);
    assert_eq!(
        Link::Offline {
            retry_in: Duration::ZERO
        }
        .tone(),
        Tone::Warn
    );
}

#[test]
fn ages_are_short() {
    let now = Instant::now();
    let ago = |s| age_short(now, now - Duration::from_secs(s));
    assert_eq!(ago(0), "now");
    assert_eq!(ago(1), "now");
    assert_eq!(ago(2), "2s");
    assert_eq!(ago(59), "59s");
    assert_eq!(ago(60), "1m");
    assert_eq!(ago(3599), "59m");
    assert_eq!(ago(7300), "2h");
}

#[test]
fn exchange_lines_are_compact_and_the_command_is_optional() {
    let now = Instant::now();
    assert_eq!(Exchange::default().sent_line(now), "no data sent");
    assert_eq!(Exchange::default().command_line(now), None);
    let ex = Exchange {
        snapshots_sent: 4312,
        last_snapshot_at: Some(now - Duration::from_secs(3)),
        last_command: Some(CommandLog {
            name: "next".into(),
            outcome: Outcome::Ok,
            at: now - Duration::from_secs(12),
        }),
    };
    assert_eq!(ex.sent_line(now), "sent 3s");
    assert_eq!(ex.command_line(now).as_deref(), Some("next, ok 12s"));
}

#[test]
fn previews_exist_for_each_link_state_and_reject_unknown_names() {
    let now = Instant::now();
    for k in [
        "connected",
        "connecting",
        "offline",
        "unauthorized",
        "failed",
    ] {
        assert!(RemoteStatus::preview(k, now).is_some(), "{k}");
    }
    assert!(RemoteStatus::preview("nope", now).is_none());
    assert_eq!(
        RemoteStatus::preview("connected", now).unwrap().link,
        Link::Connected
    );
}
