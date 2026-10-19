//! Worker decisions: what happens after each way a session can end.

use super::credentials::{CredentialStore, MemoryStore};
use super::oauth::{Http, HttpResponse};
use super::session::{Clock, Executor, TransportError};
use super::*;
use crate::player::{Command, Reply};
use std::cell::{Cell, RefCell};
use std::collections::VecDeque;
use std::rc::Rc;
use std::time::Instant;

#[derive(Clone)]
struct FakeClock(Rc<Cell<Instant>>);

impl Clock for FakeClock {
    fn now(&self) -> Instant {
        self.0.get()
    }
}

/// Plays a scripted session: each step moves the clock, then yields a frame or an error.
struct Scripted {
    clock: FakeClock,
    steps: VecDeque<(Duration, Result<Option<String>, TransportError>)>,
}

impl Transport for Scripted {
    fn send(&mut self, _: &str) -> Result<(), TransportError> {
        Ok(())
    }

    fn recv(&mut self, _timeout: Duration) -> Result<Option<String>, TransportError> {
        let (jump, result) = self
            .steps
            .pop_front()
            .unwrap_or((Duration::ZERO, Err(TransportError("script ended".into()))));
        self.clock.0.set(self.clock.0.get() + jump);
        result
    }

    fn close(&mut self) {}
}

const JOIN_OK: &str = r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":1000}}]"#;

fn frame(s: &str) -> Step {
    (Duration::ZERO, Ok(Some(s.into())))
}

fn lost_after(jump: Duration) -> Step {
    (jump, Err(TransportError("connection reset".into())))
}

fn disconnect(reason: &str) -> Step {
    frame(&format!(
        r#"["1",null,"desktop:me","disconnect",{{"reason":"{reason}"}}]"#
    ))
}

/// One step of a scripted connection: a delay, then a frame or a transport error.
type Step = (Duration, Result<Option<String>, TransportError>);

struct ScriptedDialer {
    clock: FakeClock,
    dials: RefCell<VecDeque<Result<Vec<Step>, ConnectError>>>,
    dialed: Rc<Cell<usize>>,
}

impl Dialer for ScriptedDialer {
    fn dial(&self, _token: &str) -> Result<Box<dyn Transport>, ConnectError> {
        self.dialed.set(self.dialed.get() + 1);
        match self
            .dials
            .borrow_mut()
            .pop_front()
            .unwrap_or(Err(ConnectError::Failed("nothing scripted".into())))
        {
            Ok(steps) => Ok(Box::new(Scripted {
                clock: self.clock.clone(),
                steps: steps.into(),
            })),
            Err(e) => Err(e),
        }
    }
}

/// Every refresh succeeds with a new pair, unless a failure was queued.
struct Tokens {
    failures: RefCell<VecDeque<HttpResponse>>,
    count: Cell<u32>,
}

impl Http for Rc<Tokens> {
    fn post_form(&self, _url: &str, _form: &[(&str, &str)]) -> Result<HttpResponse, String> {
        if let Some(f) = self.failures.borrow_mut().pop_front() {
            return Ok(f);
        }
        let n = self.count.get() + 1;
        self.count.set(n);
        Ok(HttpResponse {
            status: 200,
            body: format!(r#"{{"access_token":"A{n}","refresh_token":"R{n}","expires_in":3600}}"#),
        })
    }
}

struct NoExecutor;

impl Executor for NoExecutor {
    fn execute(&self, _: Command, _: Duration) -> Option<Receiver<Reply>> {
        None
    }
}

struct BrokenBrowser;

impl Browser for BrokenBrowser {
    fn open(&self, _: &str) -> Result<(), String> {
        Err("no browser".into())
    }
}

struct Fixture {
    worker: Worker,
    store: Arc<MemoryStore>,
    clock: FakeClock,
    dialed: Rc<Cell<usize>>,
    tokens: Rc<Tokens>,
}

#[derive(Clone)]
struct SharedStore(Arc<MemoryStore>);

impl CredentialStore for SharedStore {
    fn load(&self) -> Result<Option<String>, String> {
        self.0.load()
    }
    fn save(&self, t: &str) -> Result<(), String> {
        self.0.save(t)
    }
    fn delete(&self) -> Result<(), String> {
        self.0.delete()
    }
}

type Dial = Result<Vec<(Duration, Result<Option<String>, TransportError>)>, ConnectError>;

fn fixture(dials: Vec<Dial>, stored: Option<&str>) -> Fixture {
    let clock = FakeClock(Rc::new(Cell::new(Instant::now())));
    let store = Arc::new(MemoryStore::default());
    *store.value.lock().unwrap() = stored.map(str::to_string);
    let tokens = Rc::new(Tokens {
        failures: RefCell::default(),
        count: Cell::new(0),
    });
    let dialed = Rc::new(Cell::new(0));
    let auth = Auth::new(
        Box::new(tokens.clone()),
        Box::new(SharedStore(store.clone())),
        "http://localhost:4000".into(),
    );
    let mut worker = Worker::new(
        auth,
        Box::new(ScriptedDialer {
            clock: clock.clone(),
            dials: RefCell::new(dials.into()),
            dialed: dialed.clone(),
        }),
        Box::new(BrokenBrowser),
        Box::new(NoExecutor),
        Shared {
            snapshot: Arc::new(Mutex::new(Snapshot::default())),
            status: Arc::new(Mutex::new(RemoteStatus::default())),
            cancel: Arc::new(AtomicBool::new(false)),
        },
        Config::new("sess".into(), "0.1.0".into()),
    );
    worker.clock = Box::new(clock.clone());
    worker.rand = Box::new(|| 1.0); // the ceiling of every delay, to make them predictable
    Fixture {
        worker,
        store,
        clock,
        dialed,
        tokens,
    }
}

fn link(f: &Fixture) -> Link {
    lock(&f.worker.status).link.clone()
}

fn secs(n: u64) -> Duration {
    Duration::from_secs(n)
}

fn joined_then(end: (Duration, Result<Option<String>, TransportError>)) -> Dial {
    Ok(vec![frame(JOIN_OK), end])
}

#[test]
fn nobody_signed_in_means_waiting_for_the_user_without_touching_the_network() {
    let mut f = fixture(vec![], None);
    assert_eq!(f.worker.step(), Next::AwaitSignIn);
    assert_eq!(link(&f), Link::Unauthorized);
    assert_eq!(f.dialed.get(), 0);
    assert_eq!(f.tokens.count.get(), 0);
}

#[test]
fn a_lost_connection_retries_with_a_growing_delay_shown_in_the_link() {
    let mut f = fixture(
        vec![
            joined_then(lost_after(secs(1))),
            joined_then(lost_after(secs(1))),
            joined_then(lost_after(secs(1))),
        ],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::Retry(secs(1)));
    assert_eq!(link(&f), Link::Offline { retry_in: secs(1) });
    assert_eq!(f.worker.step(), Next::Retry(secs(2)));
    assert_eq!(f.worker.step(), Next::Retry(secs(4)));
}

#[test]
fn a_stable_session_resets_the_backoff() {
    let mut f = fixture(
        vec![
            joined_then(lost_after(secs(1))),
            joined_then(lost_after(secs(1))),
            joined_then(lost_after(secs(40))),
            joined_then(lost_after(secs(1))),
        ],
        Some("R0"),
    );
    f.worker.step();
    f.worker.step();
    // Joined for 40 s before the loss: the next delay starts from the beginning again.
    assert_eq!(f.worker.step(), Next::Retry(secs(1)));
    assert_eq!(f.worker.step(), Next::Retry(secs(2)));
}

#[test]
fn a_server_that_cannot_be_reached_is_offline_not_signed_out() {
    let mut f = fixture(
        vec![Err(ConnectError::Failed("connection refused".into()))],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::Retry(secs(1)));
    assert!(matches!(link(&f), Link::Offline { .. }));
    assert_eq!(f.store.load(), Ok(Some("R1".into()))); // the credential is kept (and rotated by the refresh)
}

#[test]
fn a_token_service_failure_is_offline_and_keeps_the_credential() {
    let mut f = fixture(vec![], Some("R0"));
    f.tokens.failures.borrow_mut().push_back(HttpResponse {
        status: 503,
        body: String::new(),
    });
    assert_eq!(f.worker.step(), Next::Retry(secs(1)));
    assert!(matches!(link(&f), Link::Offline { .. }));
    assert_eq!(f.store.load(), Ok(Some("R0".into())));
}

#[test]
fn a_dead_refresh_token_asks_for_a_new_sign_in() {
    let mut f = fixture(vec![], Some("R0"));
    f.tokens.failures.borrow_mut().push_back(HttpResponse {
        status: 400,
        body: r#"{"error":"invalid_grant"}"#.into(),
    });
    assert_eq!(f.worker.step(), Next::AwaitSignIn);
    assert_eq!(link(&f), Link::Unauthorized);
    assert_eq!(f.store.load(), Ok(None));
}

#[test]
fn a_refused_access_token_is_refreshed_once_then_means_sign_in_again() {
    let mut f = fixture(
        vec![
            Err(ConnectError::Unauthorized),
            Err(ConnectError::Unauthorized),
        ],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::Retry(Duration::from_millis(250)));
    assert_eq!(f.worker.step(), Next::AwaitSignIn);
    assert_eq!(link(&f), Link::Unauthorized);
    assert_eq!(f.tokens.count.get(), 2); // refreshed again between the two attempts
}

#[test]
fn a_refusal_that_a_refresh_fixes_is_forgotten() {
    let mut f = fixture(
        vec![
            Err(ConnectError::Unauthorized),
            joined_then(lost_after(secs(1))),
            Err(ConnectError::Unauthorized),
            joined_then(lost_after(secs(1))),
        ],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::Retry(Duration::from_millis(250)));
    assert_eq!(f.worker.step(), Next::Retry(secs(1)));
    // A later single refusal gets its own retry instead of being counted as a second one.
    assert_eq!(f.worker.step(), Next::Retry(Duration::from_millis(250)));
}

#[test]
fn being_replaced_waits_at_least_a_minute() {
    let mut f = fixture(vec![joined_then(disconnect("replaced"))], Some("R0"));
    match f.worker.step() {
        Next::Retry(d) => assert!(d >= secs(60), "{d:?}"),
        other => panic!("{other:?}"),
    }
    assert!(matches!(link(&f), Link::Offline { retry_in } if retry_in >= secs(60)));
}

#[test]
fn a_revoked_player_forgets_its_credential_and_waits_for_a_sign_in() {
    let mut f = fixture(vec![joined_then(disconnect("revoked"))], Some("R0"));
    assert_eq!(f.worker.step(), Next::AwaitSignIn);
    assert_eq!(link(&f), Link::Unauthorized);
    assert_eq!(f.store.load(), Ok(None));
}

#[test]
fn a_refused_join_is_a_sign_in_problem_or_a_slow_retry() {
    let mut f = fixture(
        vec![Ok(vec![frame(
            r#"["1","1","desktop:me","phx_reply",{"status":"error","response":{"reason":"forbidden"}}]"#,
        )])],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::AwaitSignIn);

    let mut f = fixture(
        vec![Ok(vec![frame(
            r#"["1","1","desktop:me","phx_reply",{"status":"error","response":{"reason":"unsupported_protocol"}}]"#,
        )])],
        Some("R0"),
    );
    assert_eq!(f.worker.step(), Next::Sleep(secs(300)));
    assert_eq!(link(&f), Link::Failed("unsupported_protocol".into()));
}

#[test]
fn signing_out_while_connected_ends_the_session_and_clears_everything() {
    let mut f = fixture(vec![Ok(vec![frame(JOIN_OK)])], Some("R0"));
    f.worker.cancel.store(true, Ordering::Relaxed);
    assert_eq!(f.worker.step(), Next::AwaitSignIn);

    lock(&f.worker.status).exchange.snapshots_sent = 5;
    f.worker.handle(Control::SignOut);
    assert_eq!(f.store.load(), Ok(None));
    assert!(!f.worker.cancel.load(Ordering::Relaxed));
    let s = lock(&f.worker.status).clone();
    assert_eq!((s.link, s.exchange.snapshots_sent), (Link::Unauthorized, 0));
    assert_eq!(f.worker.step(), Next::AwaitSignIn);
    let _ = f.clock;
}

#[test]
fn a_sign_in_that_fails_returns_to_the_sign_in_button() {
    let mut f = fixture(vec![], None);
    f.worker.handle(Control::SignIn); // the browser cannot open
    assert_eq!(link(&f), Link::Unauthorized);
}

#[test]
fn waiting_counts_down_and_wakes_on_a_control_message() {
    let f = fixture(vec![], Some("R0"));
    lock(&f.worker.status).link = Link::Offline { retry_in: secs(10) };
    let (tx, rx) = std::sync::mpsc::channel();

    let started = Instant::now();
    assert_eq!(
        f.worker.wait(
            Duration::from_millis(60),
            true,
            &rx,
            Duration::from_millis(10)
        ),
        Ok(None)
    );
    assert!(started.elapsed() >= Duration::from_millis(55));
    assert!(matches!(link(&f), Link::Offline { retry_in } if retry_in < secs(1)));

    tx.send(Control::SignOut).unwrap();
    assert_eq!(
        f.worker.wait(secs(30), true, &rx, secs(1)),
        Ok(Some(Control::SignOut))
    );

    drop(tx);
    assert_eq!(f.worker.wait(secs(30), true, &rx, secs(1)), Err(()));
}

#[test]
fn a_failure_link_is_not_overwritten_by_a_countdown() {
    let f = fixture(vec![], Some("R0"));
    lock(&f.worker.status).link = Link::Failed("x".into());
    let (_tx, rx) = std::sync::mpsc::channel();
    let _ = f.worker.wait(
        Duration::from_millis(30),
        true,
        &rx,
        Duration::from_millis(10),
    );
    assert_eq!(link(&f), Link::Failed("x".into()));
}

#[test]
fn only_https_or_a_local_http_server_is_accepted() {
    let ok = |s: &str| Settings::parse(s).map(|s| s.base_url);
    assert_eq!(
        ok("https://premiere-ecoute.fr/"),
        Ok("https://premiere-ecoute.fr".into())
    );
    assert_eq!(
        ok("http://localhost:4000"),
        Ok("http://localhost:4000".into())
    );
    assert_eq!(
        ok("http://127.0.0.1:4001"),
        Ok("http://127.0.0.1:4001".into())
    );
    assert!(ok("http://premiere-ecoute.fr").is_err());
    assert!(ok("ftp://localhost").is_err());
    assert!(ok("not a url").is_err());
    assert!(ok("").is_err());
}

#[test]
fn the_socket_address_follows_the_scheme_and_adds_the_path_and_version() {
    let ws = |s: &str| Settings::parse(s).unwrap().ws_url();
    assert_eq!(
        ws("http://localhost:4000"),
        "ws://localhost:4000/player/websocket?vsn=2.0.0"
    );
    assert_eq!(
        ws("https://premiere-ecoute.fr"),
        "wss://premiere-ecoute.fr/player/websocket?vsn=2.0.0"
    );
}
