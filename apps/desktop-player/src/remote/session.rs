//! One connection to the backend, from join to the end. A state machine written against a
//! `Transport` and a `Clock`, so reconnect, heartbeat, expiry and dedup behaviour are tested
//! without a network or real time.

use super::protocol::{self, Disconnect, Inbound, RemoteCommand};
use super::retry::SeenIds;
use crate::player::{Command, Reply, Request, Snapshot, lock};
use crate::remote_status::{CommandLog, Link, Outcome, RemoteStatus};
use std::sync::Mutex;
use std::sync::mpsc::{Receiver, Sender, TryRecvError};
use std::time::{Duration, Instant};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TransportError(pub String);

pub trait Transport {
    fn send(&mut self, frame: &str) -> Result<(), TransportError>;
    /// The next text frame, or `None` when `timeout` passed with nothing to read.
    fn recv(&mut self, timeout: Duration) -> Result<Option<String>, TransportError>;
    fn close(&mut self);
}

pub trait Clock {
    fn now(&self) -> Instant;
}

pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> Instant {
        Instant::now()
    }
}

/// How commands reach the player worker.
pub trait Executor {
    /// Starts the command; the receiver yields what happened. `None` when the worker is gone.
    fn execute(&self, command: Command, ttl: Duration) -> Option<Receiver<Reply>>;
}

impl Executor for Sender<Request> {
    fn execute(&self, command: Command, ttl: Duration) -> Option<Receiver<Reply>> {
        let (request, reply) = Request::remote(command, ttl);
        self.send(request).ok().map(|()| reply)
    }
}

#[derive(Clone, Debug)]
pub struct Config {
    pub session_id: String,
    pub app_version: String,
    /// How often the loop wakes up to service timers.
    pub tick: Duration,
    pub heartbeat_every: Duration,
    pub heartbeat_timeout: Duration,
    pub join_timeout: Duration,
}

impl Config {
    pub fn new(session_id: String, app_version: String) -> Self {
        Self {
            session_id,
            app_version,
            tick: Duration::from_millis(100),
            heartbeat_every: Duration::from_secs(25),
            heartbeat_timeout: Duration::from_secs(10),
            join_timeout: Duration::from_secs(10),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum End {
    /// Network error, timeout, or the server closed the channel: reconnect with backoff.
    Lost(String),
    /// Another connection of the same user took over: wait before reconnecting.
    Replaced,
    /// The user disconnected the player: do not reconnect before a new login.
    Revoked,
    /// The join was refused (`forbidden`, `unsupported_protocol`).
    Refused(String),
    /// The caller asked to stop (the user signed out).
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Ended {
    pub reason: End,
    /// How long the channel was joined; the caller resets its backoff after a stable run.
    pub joined_for: Duration,
}

struct InFlight {
    id: String,
    name: String,
    reply: Receiver<Reply>,
    give_up_at: Instant,
}

pub struct Session<'a, T: Transport + ?Sized, C: Clock + ?Sized, E: Executor + ?Sized> {
    pub transport: &'a mut T,
    pub clock: &'a C,
    pub executor: &'a E,
    pub snapshot: &'a dyn Fn() -> Snapshot,
    pub status: &'a Mutex<RemoteStatus>,
    pub config: &'a Config,
    /// Polled every tick; `true` ends the session.
    pub cancelled: &'a dyn Fn() -> bool,
}

const JOIN_REF: &str = "1";
/// A command that never answered is dropped after its ttl plus this much.
const REPLY_GRACE: Duration = Duration::from_secs(5);

impl<T: Transport + ?Sized, C: Clock + ?Sized, E: Executor + ?Sized> Session<'_, T, C, E> {
    pub fn run(self) -> Ended {
        let Session {
            transport,
            clock,
            executor,
            snapshot,
            status,
            config,
            cancelled,
        } = self;
        let mut msg_ref = 1u64;
        let mut seq = 0u64;
        let mut seen = SeenIds::new(256);
        let mut inflight: Vec<InFlight> = Vec::new();
        let mut joined_at: Option<Instant> = None;
        let mut interval = Duration::from_secs(1);
        let mut next_snapshot = clock.now();
        let mut next_heartbeat = clock.now() + config.heartbeat_every;
        let mut heartbeat_sent: Option<Instant> = None;
        let started = clock.now();

        let lost = |transport: &mut T, joined_at: Option<Instant>, now: Instant, why: &str| {
            transport.close();
            Ended {
                reason: End::Lost(why.into()),
                joined_for: joined_at.map_or(Duration::ZERO, |t| now.saturating_duration_since(t)),
            }
        };
        let ended = |transport: &mut T, joined_at: Option<Instant>, now: Instant, reason: End| {
            transport.close();
            Ended {
                reason,
                joined_for: joined_at.map_or(Duration::ZERO, |t| now.saturating_duration_since(t)),
            }
        };

        if let Err(e) = transport.send(&protocol::join(
            JOIN_REF,
            &config.session_id,
            &config.app_version,
        )) {
            return lost(transport, None, clock.now(), &e.0);
        }

        loop {
            let frame = match transport.recv(config.tick) {
                Ok(f) => f,
                Err(e) => return lost(transport, joined_at, clock.now(), &e.0),
            };
            let now = clock.now();
            if cancelled() {
                return ended(transport, joined_at, now, End::Cancelled);
            }

            if let Some(text) = frame {
                // Frames we cannot read are ignored: a misbehaving server must not crash the player.
                if let Ok(f) = protocol::decode_frame(&text) {
                    match protocol::interpret(&f) {
                        Inbound::JoinOk { snapshot_interval } if joined_at.is_none() => {
                            joined_at = Some(now);
                            interval = snapshot_interval;
                            next_snapshot = now; // first snapshot immediately: the backend waits 5 s for it
                            lock(status).link = Link::Connected;
                        }
                        Inbound::JoinOk { .. } => {}
                        Inbound::JoinRefused { reason } => {
                            return ended(transport, joined_at, now, End::Refused(reason));
                        }
                        Inbound::HeartbeatReply => heartbeat_sent = None,
                        Inbound::Disconnect(Disconnect::Replaced) => {
                            return ended(transport, joined_at, now, End::Replaced);
                        }
                        Inbound::Disconnect(Disconnect::Revoked) => {
                            return ended(transport, joined_at, now, End::Revoked);
                        }
                        Inbound::Disconnect(Disconnect::Other(why)) => {
                            return lost(
                                transport,
                                joined_at,
                                now,
                                &format!("disconnected: {why}"),
                            );
                        }
                        Inbound::ChannelEnded => {
                            return lost(transport, joined_at, now, "channel closed");
                        }
                        Inbound::Command(parsed) if joined_at.is_some() => {
                            let acks = on_command(parsed, &mut seen, executor, &mut inflight, now);
                            for (id, name, outcome, error) in acks {
                                msg_ref += 1;
                                if let Err(e) = transport.send(&protocol::ack(
                                    JOIN_REF,
                                    msg_ref,
                                    &id,
                                    outcome,
                                    error.as_deref(),
                                )) {
                                    return lost(transport, joined_at, now, &e.0);
                                }
                                record(status, name, outcome, now);
                            }
                        }
                        Inbound::Command(_) | Inbound::Ignored => {}
                    }
                }
            }

            if joined_at.is_none() {
                if now.saturating_duration_since(started) >= config.join_timeout {
                    return lost(transport, None, now, "join timed out");
                }
                continue;
            }

            // Answers from the player worker.
            let mut finished = Vec::new();
            inflight.retain(|c| match c.reply.try_recv() {
                Ok(reply) => {
                    finished.push((c.id.clone(), c.name.clone(), reply));
                    false
                }
                Err(TryRecvError::Disconnected) => false, // the worker died mid-command: outcome unknown, no ack
                Err(TryRecvError::Empty) => now < c.give_up_at,
            });
            for (id, name, reply) in finished {
                let (outcome, error) = match reply {
                    Reply::Done => (Outcome::Ok, None),
                    Reply::Failed(message) => (Outcome::Error, Some(message)),
                    Reply::Expired => (Outcome::Expired, None),
                };
                msg_ref += 1;
                if let Err(e) = transport.send(&protocol::ack(
                    JOIN_REF,
                    msg_ref,
                    &id,
                    outcome,
                    error.as_deref(),
                )) {
                    return lost(transport, joined_at, now, &e.0);
                }
                record(status, name, outcome, now);
            }

            if now >= next_snapshot {
                seq += 1;
                msg_ref += 1;
                if let Err(e) =
                    transport.send(&protocol::snapshot(JOIN_REF, msg_ref, seq, &snapshot()))
                {
                    return lost(transport, joined_at, now, &e.0);
                }
                {
                    let mut s = lock(status);
                    s.exchange.snapshots_sent += 1;
                    s.exchange.last_snapshot_at = Some(now);
                }
                next_snapshot = now + interval;
            }

            if let Some(sent) = heartbeat_sent {
                if now.saturating_duration_since(sent) >= config.heartbeat_timeout {
                    return lost(transport, joined_at, now, "heartbeat timed out");
                }
            } else if now >= next_heartbeat {
                msg_ref += 1;
                if let Err(e) = transport.send(&protocol::heartbeat(msg_ref)) {
                    return lost(transport, joined_at, now, &e.0);
                }
                heartbeat_sent = Some(now);
                next_heartbeat = now + config.heartbeat_every;
            }
        }
    }
}

fn record(status: &Mutex<RemoteStatus>, name: String, outcome: Outcome, at: Instant) {
    lock(status).exchange.last_command = Some(CommandLog { name, outcome, at });
}

type Ack = (String, String, Outcome, Option<String>);

/// Validates, dedups and starts one command. Returns the acks that can be sent right away.
fn on_command(
    parsed: Result<RemoteCommand, protocol::Rejection>,
    seen: &mut SeenIds,
    executor: &(impl Executor + ?Sized),
    inflight: &mut Vec<InFlight>,
    now: Instant,
) -> Vec<Ack> {
    match parsed {
        Err(rejection) => match rejection.id {
            // Without an id there is nothing to acknowledge.
            None => Vec::new(),
            Some(id) if !seen.insert(&id) => vec![(id, "invalid".into(), Outcome::Duplicate, None)],
            Some(id) => vec![(
                id,
                "invalid".into(),
                Outcome::Rejected,
                Some(rejection.reason),
            )],
        },
        Ok(c) if !seen.insert(&c.id) => vec![(c.id, c.name, Outcome::Duplicate, None)],
        Ok(c) => match executor.execute(c.command.clone(), c.ttl) {
            None => vec![(
                c.id,
                c.name,
                Outcome::Error,
                Some("the player is not available".into()),
            )],
            Some(reply) => {
                inflight.push(InFlight {
                    id: c.id,
                    name: c.name,
                    reply,
                    give_up_at: now + c.ttl + REPLY_GRACE,
                });
                Vec::new()
            }
        },
    }
}

#[cfg(test)]
mod tests;
