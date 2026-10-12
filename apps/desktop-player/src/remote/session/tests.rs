use super::*;
use crate::player::Playback;
use serde_json::{Value, json};
use std::cell::{Cell, RefCell};
use std::collections::VecDeque;
use std::rc::Rc;

#[derive(Clone)]
struct FakeClock(Rc<Cell<Instant>>);

impl FakeClock {
    fn new() -> Self {
        Self(Rc::new(Cell::new(Instant::now())))
    }
}

impl Clock for FakeClock {
    fn now(&self) -> Instant {
        self.0.get()
    }
}

enum Step {
    Frame(String),
    Fail(String),
    /// Nothing to read for one `recv`.
    Idle,
}

/// Every `recv` advances the fake clock by the timeout it was given.
struct FakeTransport {
    clock: FakeClock,
    script: VecDeque<Step>,
    sent: Vec<Value>,
    closed: bool,
    calls: usize,
}

impl FakeTransport {
    fn new(clock: &FakeClock, script: Vec<Step>) -> Self {
        Self { clock: clock.clone(), script: script.into(), sent: Vec::new(), closed: false, calls: 0 }
    }

    fn events(&self) -> Vec<String> {
        self.sent.iter().map(|f| f[3].as_str().unwrap().to_string()).collect()
    }

    fn acks(&self) -> Vec<(String, String)> {
        self.sent
            .iter()
            .filter(|f| f[3] == "ack")
            .map(|f| (f[4]["command_id"].as_str().unwrap().into(), f[4]["status"].as_str().unwrap().into()))
            .collect()
    }
}

impl Transport for FakeTransport {
    fn send(&mut self, frame: &str) -> Result<(), TransportError> {
        self.sent.push(serde_json::from_str(frame).unwrap());
        Ok(())
    }

    fn recv(&mut self, timeout: Duration) -> Result<Option<String>, TransportError> {
        self.calls += 1;
        assert!(self.calls < 5_000, "the session never ended");
        self.clock.0.set(self.clock.0.get() + timeout);
        match self.script.pop_front() {
            Some(Step::Frame(f)) => Ok(Some(f)),
            Some(Step::Fail(e)) => Err(TransportError(e)),
            Some(Step::Idle) | None => Ok(None),
        }
    }

    fn close(&mut self) {
        self.closed = true;
    }
}

struct FakeExecutor {
    replies: RefCell<VecDeque<Reply>>,
    started: RefCell<Vec<Command>>,
}

impl FakeExecutor {
    fn answering(replies: Vec<Reply>) -> Self {
        Self { replies: RefCell::new(replies.into()), started: RefCell::new(Vec::new()) }
    }
}

impl Executor for FakeExecutor {
    fn execute(&self, command: Command, _ttl: Duration) -> Option<Receiver<Reply>> {
        self.started.borrow_mut().push(command);
        let (tx, rx) = std::sync::mpsc::channel();
        if let Some(reply) = self.replies.borrow_mut().pop_front() {
            tx.send(reply).unwrap();
        }
        std::mem::forget(tx); // keep the channel open when there is no reply: the command hangs
        Some(rx)
    }
}

const JOIN_OK: &str = r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":1000}}]"#;

fn command(id: &str, ty: &str, args: Value) -> Step {
    Step::Frame(json!(["1", null, "desktop:me", "command", {"id": id, "type": ty, "args": args, "ttl_ms": 10000}]).to_string())
}

fn frame(s: &str) -> Step {
    Step::Frame(s.into())
}

fn drive(script: Vec<Step>, executor: &FakeExecutor, config: Config) -> (Ended, FakeTransport, Mutex<RemoteStatus>, FakeClock) {
    let clock = FakeClock::new();
    let mut transport = FakeTransport::new(&clock, script);
    let status = Mutex::new(RemoteStatus::default());
    let snapshot = || Snapshot { running: true, playback: Playback::Playing, title: "T".into(), ..Snapshot::default() };
    let ended = Session { transport: &mut transport, clock: &clock, executor, snapshot: &snapshot, status: &status, config: &config, cancelled: &|| false }.run();
    (ended, transport, status, clock)
}

fn config() -> Config {
    Config::new("sess".into(), "0.1.0".into())
}

fn silence(n: usize) -> Vec<Step> {
    (0..n).map(|_| Step::Idle).collect()
}

fn revoked() -> Step {
    frame(r#"["1",null,"desktop:me","disconnect",{"reason":"revoked"}]"#)
}

fn replaced() -> Step {
    frame(r#"["1",null,"desktop:me","disconnect",{"reason":"replaced"}]"#)
}

#[test]
fn it_joins_then_sends_the_first_snapshot_immediately() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(JOIN_OK), revoked()];
    let (ended, t, status, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Revoked);
    assert_eq!(t.events(), ["phx_join", "snapshot"]);
    assert_eq!(t.sent[1][4]["seq"], 1);
    assert_eq!(lock(&status).exchange.snapshots_sent, 1);
    assert!(t.closed);
}

#[test]
fn snapshots_follow_the_interval_with_increasing_seq() {
    let ex = FakeExecutor::answering(vec![]);
    // 35 empty frames at 100 ms each = 3.5 s of silence after the join.
    let mut script = vec![frame(JOIN_OK)];
    script.extend(silence(35));
    script.push(replaced());
    let (ended, t, _, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Replaced);
    let seqs: Vec<_> = t.sent.iter().filter(|f| f[3] == "snapshot").map(|f| f[4]["seq"].as_u64().unwrap()).collect();
    assert_eq!(seqs, [1, 2, 3, 4]);
}

fn acked(script_cmds: Vec<Step>, replies: Vec<Reply>) -> (Vec<(String, String)>, Vec<Command>, Vec<Value>) {
    let ex = FakeExecutor::answering(replies);
    let mut script = vec![frame(JOIN_OK)];
    script.extend(script_cmds);
    script.extend(silence(3));
    script.push(revoked());
    let (_, t, _, _) = drive(script, &ex, config());
    let started = ex.started.borrow().clone();
    (t.acks(), started, t.sent)
}

#[test]
fn a_valid_command_runs_and_is_acked_ok() {
    let ex = FakeExecutor::answering(vec![Reply::Done]);
    let mut script = vec![frame(JOIN_OK), command("c1", "next", json!({}))];
    script.extend(silence(3));
    script.push(revoked());
    let (_, t, status, _) = drive(script, &ex, config());
    assert_eq!(*ex.started.borrow(), [Command::Next]);
    assert_eq!(t.acks(), [("c1".to_string(), "ok".to_string())]);
    let log = lock(&status).exchange.last_command.clone().unwrap();
    assert_eq!((log.name.as_str(), log.outcome), ("next", Outcome::Ok));
}

#[test]
fn a_repeated_command_id_is_acked_duplicate_and_not_run_twice() {
    let (acks, started, _) = acked(vec![command("c1", "next", json!({})), command("c1", "next", json!({}))], vec![Reply::Done]);
    assert_eq!(started, [Command::Next]);
    assert_eq!(acks, [("c1".to_string(), "ok".to_string()), ("c1".to_string(), "duplicate".to_string())]);
}

#[test]
fn an_invalid_command_is_rejected_and_never_reaches_the_player() {
    let (acks, started, sent) = acked(vec![command("c1", "format_disk", json!({})), command("c2", "set_volume", json!({"volume": 9}))], vec![]);
    assert!(started.is_empty());
    assert_eq!(acks, [("c1".to_string(), "rejected".to_string()), ("c2".to_string(), "rejected".to_string())]);
    let ack = sent.iter().find(|f| f[3] == "ack").unwrap();
    assert!(ack[4]["error"].as_str().unwrap().contains("unknown command type"));
}

#[test]
fn a_failed_command_is_acked_error_with_the_message_and_an_expired_one_expired() {
    let (acks, _, sent) = acked(
        vec![command("c1", "next", json!({})), command("c2", "previous", json!({}))],
        vec![Reply::Failed("Spotify did not accept the command".into()), Reply::Expired],
    );
    assert_eq!(acks, [("c1".to_string(), "error".to_string()), ("c2".to_string(), "expired".to_string())]);
    let err = sent.iter().find(|f| f[3] == "ack" && f[4]["status"] == "error").unwrap();
    assert_eq!(err[4]["error"], "Spotify did not accept the command");
}

#[test]
fn commands_before_the_join_is_confirmed_are_ignored() {
    let ex = FakeExecutor::answering(vec![Reply::Done]);
    let script = vec![command("c1", "next", json!({})), frame(JOIN_OK), revoked()];
    let (_, _, _, _) = drive(script, &ex, config());
    assert!(ex.started.borrow().is_empty());
}

#[test]
fn a_refused_join_ends_the_session_with_the_reason() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(r#"["1","1","desktop:me","phx_reply",{"status":"error","response":{"reason":"unsupported_protocol"}}]"#)];
    let (ended, t, _, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Refused("unsupported_protocol".into()));
    assert_eq!(t.events(), ["phx_join"]);
}

#[test]
fn a_join_that_is_never_answered_times_out() {
    let ex = FakeExecutor::answering(vec![]);
    let (ended, _, _, clock) = drive(vec![], &ex, config());
    assert_eq!(ended.reason, End::Lost("join timed out".into()));
    assert!(clock.now() >= Instant::now());
}

#[test]
fn a_transport_error_is_a_lost_connection_and_the_transport_is_closed() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(JOIN_OK), Step::Fail("connection reset".into())];
    let (ended, t, _, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Lost("connection reset".into()));
    assert!(t.closed);
}

#[test]
fn the_server_closing_the_channel_is_a_lost_connection() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(JOIN_OK), frame(r#"["1",null,"desktop:me","phx_close",{}]"#)];
    let (ended, _, _, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Lost("channel closed".into()));
}

#[test]
fn heartbeats_are_sent_and_a_missing_reply_ends_the_session() {
    let ex = FakeExecutor::answering(vec![]);
    let mut cfg = config();
    cfg.heartbeat_every = Duration::from_secs(2);
    cfg.heartbeat_timeout = Duration::from_secs(1);
    // Silence forever after the join: the heartbeat goes out, nobody answers.
    let (ended, t, _, _) = drive(vec![frame(JOIN_OK)], &ex, cfg);
    assert_eq!(ended.reason, End::Lost("heartbeat timed out".into()));
    assert_eq!(t.events().iter().filter(|e| *e == "heartbeat").count(), 1);
}

#[test]
fn garbage_frames_are_ignored() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(JOIN_OK), frame("not json"), frame("[1,2]"), frame(r#"["1",null,"desktop:me","mystery",{}]"#), replaced()];
    let (ended, _, _, _) = drive(script, &ex, config());
    assert_eq!(ended.reason, End::Replaced);
}

#[test]
fn the_session_reports_how_long_it_was_joined() {
    let ex = FakeExecutor::answering(vec![]);
    let mut script = vec![frame(JOIN_OK)];
    script.extend(silence(50));
    script.push(replaced());
    let (ended, _, _, _) = drive(script, &ex, config());
    assert!(ended.joined_for >= Duration::from_secs(5), "{:?}", ended.joined_for);
}

#[test]
fn a_cancelled_session_ends_at_once_and_closes_the_transport() {
    let ex = FakeExecutor::answering(vec![]);
    let clock = FakeClock::new();
    let mut transport = FakeTransport::new(&clock, vec![frame(JOIN_OK)]);
    let status = Mutex::new(RemoteStatus::default());
    let snapshot = Snapshot::default;
    let calls = Cell::new(0);
    let cancelled = || {
        calls.set(calls.get() + 1);
        calls.get() > 3
    };
    let cfg = config();
    let ended = Session { transport: &mut transport, clock: &clock, executor: &ex, snapshot: &snapshot, status: &status, config: &cfg, cancelled: &cancelled }.run();
    assert_eq!(ended.reason, End::Cancelled);
    assert!(transport.closed);
}

#[test]
fn the_status_shows_connected_after_the_join() {
    let ex = FakeExecutor::answering(vec![]);
    let script = vec![frame(JOIN_OK), revoked()];
    let (_, _, status, _) = drive(script, &ex, config());
    assert_eq!(lock(&status).link, Link::Connected);
}
