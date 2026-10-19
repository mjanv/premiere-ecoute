//! Connection to the Première Écoute backend (ADR 0001 and `docs/guides/desktop-player.md` in the
//! monorepo root).
//!
//! One supervised worker thread owns the whole lifecycle: sign in, get an access token, dial,
//! run a session, and decide what to do when it ends. Nothing here can block or crash the local
//! player: the worker talks to it only through the request channel and the shared snapshot.

pub mod auth;
pub mod config;
pub mod credentials;
pub mod http;
pub mod oauth;
pub mod protocol;
pub mod retry;
pub mod session;
pub mod transport;

use crate::player::{Request, Snapshot, lock};
use crate::remote_status::{Exchange, Link, RemoteStatus};
use crate::supervise::{self, Decision, Policy};
use auth::{Auth, Browser};
use oauth::AuthError;
use retry::Backoff;
use session::{Clock, Config, End, Executor, Session, SystemClock, Transport};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use transport::{ConnectError, WsTransport};
use url::Url;

/// A session that lasted this long counts as stable: the backoff starts over.
const STABLE: Duration = Duration::from_secs(30);
/// Another connection took over; coming back at once would start a tug of war.
const AFTER_REPLACED: Duration = Duration::from_secs(60);
/// The server refused our protocol: retrying quickly cannot help.
const AFTER_FAILED: Duration = Duration::from_secs(300);
const SIGN_IN_TIMEOUT: Duration = Duration::from_secs(300);
const WAIT_SLICE: Duration = Duration::from_secs(1);

// ---- settings ------------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Settings {
    pub base_url: String,
}

fn is_loopback(host: &str) -> bool {
    matches!(host, "localhost" | "127.0.0.1" | "[::1]" | "::1")
}

impl Settings {
    /// The server to connect to: `PLAYER_HUB_URL` if set, else the address saved from the window.
    /// Neither means the build's own server (`config::DEFAULT_SERVER`).
    pub fn configured() -> Result<Self, String> {
        let env = std::env::var("PLAYER_HUB_URL").ok();
        let address = config::resolve(
            env.as_deref(),
            config::load().as_deref(),
            config::DEFAULT_SERVER,
        );
        Self::parse(&address)
    }

    /// Plain `http://` is accepted for the machine itself only; anything else must be `https://`.
    pub fn parse(base: &str) -> Result<Self, String> {
        let url = Url::parse(base).map_err(|e| format!("The server address is not valid ({e})"))?;
        let host = url.host_str().ok_or("The server address has no host")?;
        match url.scheme() {
            "https" => {}
            "http" if is_loopback(host) => {}
            "http" => {
                return Err(
                    "The server address must use https, unless the server runs on this PC".into(),
                );
            }
            _ => return Err("The server address must start with https://".into()),
        }
        Ok(Self {
            base_url: base.trim_end_matches('/').to_string(),
        })
    }

    pub fn ws_url(&self) -> String {
        let mut url = Url::parse(&self.base_url).expect("validated in parse");
        let scheme = if url.scheme() == "https" { "wss" } else { "ws" };
        url.set_scheme(scheme)
            .expect("http and https can become ws and wss");
        url.set_path("/player/websocket");
        url.set_query(Some("vsn=2.0.0"));
        url.to_string()
    }
}

// ---- collaborators -------------------------------------------------------------------------

pub trait Dialer {
    fn dial(&self, access_token: &str) -> Result<Box<dyn Transport>, ConnectError>;
}

pub struct WsDialer {
    pub ws_url: String,
}

impl Dialer for WsDialer {
    fn dial(&self, access_token: &str) -> Result<Box<dyn Transport>, ConnectError> {
        WsTransport::connect(&self.ws_url, access_token).map(|t| Box::new(t) as Box<dyn Transport>)
    }
}

/// Opens the system browser, for `http(s)` addresses only.
#[cfg(windows)]
pub struct WindowsBrowser;

#[cfg(windows)]
impl Browser for WindowsBrowser {
    fn open(&self, url: &str) -> Result<(), String> {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        if !(url.starts_with("https://") || url.starts_with("http://")) {
            return Err("refusing to open a non-web address".into());
        }
        std::process::Command::new("rundll32")
            .args(["url.dll,FileProtocolHandler", url])
            .creation_flags(CREATE_NO_WINDOW)
            .spawn()
            .map(drop)
            .map_err(|e| e.to_string())
    }
}

// ---- the worker ----------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Control {
    SignIn,
    SignOut,
}

/// What the driver does after one pass.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Next {
    /// Wait, showing the countdown, then try again.
    Retry(Duration),
    /// Wait without a countdown (the link shows a failure), then try again.
    Sleep(Duration),
    /// Nothing to do until the user signs in.
    AwaitSignIn,
}

/// State the worker shares with the rest of the app.
pub struct Shared {
    pub snapshot: Arc<Mutex<Snapshot>>,
    pub status: Arc<Mutex<RemoteStatus>>,
    pub cancel: Arc<AtomicBool>,
}

pub struct Worker {
    pub auth: Auth,
    pub dialer: Box<dyn Dialer>,
    pub browser: Box<dyn Browser>,
    pub executor: Box<dyn Executor>,
    pub clock: Box<dyn Clock>,
    pub snapshot: Arc<Mutex<Snapshot>>,
    pub status: Arc<Mutex<RemoteStatus>>,
    pub config: Config,
    pub rand: Box<dyn Fn() -> f64>,
    pub cancel: Arc<AtomicBool>,
    backoff: Backoff,
    /// The socket refused our access token once; a second refusal means the sign-in is no good.
    refused_once: bool,
}

impl Worker {
    pub fn new(
        auth: Auth,
        dialer: Box<dyn Dialer>,
        browser: Box<dyn Browser>,
        executor: Box<dyn Executor>,
        shared: Shared,
        config: Config,
    ) -> Self {
        let Shared {
            snapshot,
            status,
            cancel,
        } = shared;
        Self {
            auth,
            dialer,
            browser,
            executor,
            clock: Box::new(SystemClock),
            snapshot,
            status,
            config,
            rand: Box::new(fastrand::f64),
            cancel,
            backoff: Backoff::default(),
            refused_once: false,
        }
    }

    fn set_link(&self, link: Link) {
        lock(&self.status).link = link;
    }

    fn offline(&mut self) -> Next {
        let delay = self.backoff.next_delay((self.rand)());
        self.set_link(Link::Offline { retry_in: delay });
        Next::Retry(delay)
    }

    fn sign_in_needed(&self) -> Next {
        self.set_link(Link::Unauthorized);
        Next::AwaitSignIn
    }

    /// One pass: token, dial, session, and what to do next.
    pub fn step(&mut self) -> Next {
        let token = match self.auth.access_token(self.clock.now()) {
            Ok(token) => token,
            Err(AuthError::NotEnrolled | AuthError::Unauthorized(_)) => {
                return self.sign_in_needed();
            }
            Err(_) => return self.offline(),
        };
        self.set_link(Link::Connecting);
        let mut transport = match self.dialer.dial(&token) {
            Ok(transport) => transport,
            Err(ConnectError::Unauthorized) if !self.refused_once => {
                // Maybe the token expired in flight: refresh once before giving up.
                self.refused_once = true;
                self.auth.invalidate_access();
                return Next::Retry(Duration::from_millis(250));
            }
            Err(ConnectError::Unauthorized) => {
                self.refused_once = false;
                return self.sign_in_needed();
            }
            Err(ConnectError::Failed(_)) => return self.offline(),
        };
        self.refused_once = false;

        let cancel = self.cancel.clone();
        let snapshot = self.snapshot.clone();
        let cancelled = move || cancel.load(Ordering::Relaxed);
        let current = move || lock(&snapshot).clone();
        let ended = Session {
            transport: transport.as_mut(),
            clock: self.clock.as_ref(),
            executor: self.executor.as_ref(),
            snapshot: &current,
            status: &self.status,
            config: &self.config,
            cancelled: &cancelled,
        }
        .run();

        if ended.joined_for >= STABLE {
            self.backoff.reset();
        }
        match ended.reason {
            End::Lost(_) => self.offline(),
            End::Replaced => {
                let delay = self.backoff.next_delay((self.rand)()).max(AFTER_REPLACED);
                self.set_link(Link::Offline { retry_in: delay });
                Next::Retry(delay)
            }
            End::Revoked => {
                // The user disconnected this PC: the credential is useless.
                self.auth.discard();
                self.sign_in_needed()
            }
            End::Refused(reason) if reason == "forbidden" => self.sign_in_needed(),
            End::Refused(reason) => {
                self.set_link(Link::Failed(reason));
                Next::Sleep(AFTER_FAILED)
            }
            End::Cancelled => self.sign_in_needed(),
        }
    }

    pub fn handle(&mut self, control: Control) {
        match control {
            Control::SignIn => {
                self.set_link(Link::SigningIn);
                match self
                    .auth
                    .sign_in(self.browser.as_ref(), SIGN_IN_TIMEOUT, self.clock.now())
                {
                    Ok(()) => {
                        self.backoff.reset();
                        self.set_link(Link::Connecting);
                    }
                    // Declined, timed out, no browser: back to the button.
                    Err(_) => self.set_link(Link::Unauthorized),
                }
            }
            Control::SignOut => {
                self.cancel.store(false, Ordering::Relaxed);
                self.auth.forget();
                self.backoff.reset();
                *lock(&self.status) = RemoteStatus {
                    link: Link::Unauthorized,
                    exchange: Exchange::default(),
                };
            }
        }
    }

    /// Waits up to `total`, counting down in the link, and returns early on a control message.
    /// `Err` when the app is shutting down (nobody can send controls any more).
    pub fn wait(
        &self,
        total: Duration,
        countdown: bool,
        control: &Receiver<Control>,
        slice: Duration,
    ) -> Result<Option<Control>, ()> {
        let mut left = total;
        while !left.is_zero() {
            if countdown {
                let mut s = lock(&self.status);
                if matches!(s.link, Link::Offline { .. }) {
                    s.link = Link::Offline { retry_in: left };
                }
            }
            let nap = left.min(slice);
            match control.recv_timeout(nap) {
                Ok(c) => return Ok(Some(c)),
                Err(RecvTimeoutError::Timeout) => left -= nap,
                Err(RecvTimeoutError::Disconnected) => return Err(()),
            }
        }
        Ok(None)
    }
}

/// Runs the worker until the control channel closes.
pub fn drive(worker: &mut Worker, control: &Receiver<Control>, slice: Duration) {
    loop {
        match worker.step() {
            Next::Retry(delay) => match worker.wait(delay, true, control, slice) {
                Ok(Some(c)) => worker.handle(c),
                Ok(None) => {}
                Err(()) => return,
            },
            Next::Sleep(delay) => match worker.wait(delay, false, control, slice) {
                Ok(Some(c)) => worker.handle(c),
                Ok(None) => {}
                Err(()) => return,
            },
            Next::AwaitSignIn => match control.recv() {
                Ok(c) => worker.handle(c),
                Err(_) => return,
            },
        }
    }
}

// ---- public handle -------------------------------------------------------------------------

/// What the window uses to talk to the remote worker.
#[derive(Clone)]
pub struct Handle {
    control: Sender<Control>,
    cancel: Arc<AtomicBool>,
}

impl Handle {
    pub fn sign_in(&self) {
        let _ = self.control.send(Control::SignIn);
    }

    pub fn sign_out(&self) {
        self.cancel.store(true, Ordering::Relaxed);
        let _ = self.control.send(Control::SignOut);
    }
}

fn session_id() -> String {
    let mut bytes = [0u8; 16];
    getrandom::fill(&mut bytes).expect("the OS random generator is available");
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Starts the supervised remote worker. `commands` is the player's request channel.
pub fn start(
    settings: Settings,
    snapshot: Arc<Mutex<Snapshot>>,
    commands: Sender<Request>,
    status: Arc<Mutex<RemoteStatus>>,
) -> Handle {
    let (control_tx, control_rx) = std::sync::mpsc::channel();
    let cancel = Arc::new(AtomicBool::new(false));
    let handle = Handle {
        control: control_tx,
        cancel: cancel.clone(),
    };

    let crash_status = status.clone();
    let on_crash = move |decision: &Decision, message: &str| {
        let restart = match decision {
            Decision::Restart { after } => format!("restarting in {} s", after.as_secs().max(1)),
            Decision::CoolOff { after } => format!("paused for {} min", after.as_secs() / 60),
        };
        lock(&crash_status).link = Link::Failed(format!("{message}, {restart}"));
    };

    supervise::supervise("remote-worker", Policy::default(), on_crash, move || {
        #[cfg(windows)]
        let store: Box<dyn credentials::CredentialStore> =
            Box::new(credentials::WindowsStore::for_server(&settings.base_url));
        #[cfg(not(windows))]
        let store: Box<dyn credentials::CredentialStore> =
            Box::new(credentials::MemoryStore::default());
        #[cfg(windows)]
        let browser: Box<dyn Browser> = Box::new(WindowsBrowser);
        #[cfg(not(windows))]
        let browser: Box<dyn Browser> = Box::new(NoBrowser);

        let auth = Auth::new(
            Box::new(http::UreqHttp::new()),
            store,
            settings.base_url.clone(),
        );
        let mut worker = Worker::new(
            auth,
            Box::new(WsDialer {
                ws_url: settings.ws_url(),
            }),
            browser,
            Box::new(commands.clone()),
            Shared {
                snapshot: snapshot.clone(),
                status: status.clone(),
                cancel: cancel.clone(),
            },
            Config::new(session_id(), env!("CARGO_PKG_VERSION").to_string()),
        );
        drive(&mut worker, &control_rx, WAIT_SLICE);
    });
    handle
}

#[cfg(not(windows))]
struct NoBrowser;

#[cfg(not(windows))]
impl Browser for NoBrowser {
    fn open(&self, _: &str) -> Result<(), String> {
        Err("no browser on this platform".into())
    }
}

#[cfg(test)]
mod tests;
