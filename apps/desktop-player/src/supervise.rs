//! Restarting workers the way an OTP supervisor does: a crashed worker is restarted with backoff;
//! too many crashes in a window means a cool-off, not a dead process.

use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug)]
pub struct Policy {
    pub max_restarts: usize,
    pub window: Duration,
    pub backoff: Duration,
    pub max_backoff: Duration,
    pub cooloff: Duration,
}

impl Default for Policy {
    /// At most 5 restarts within 60 s, then wait 5 minutes before trying again.
    fn default() -> Self {
        Self {
            max_restarts: 5,
            window: Duration::from_secs(60),
            backoff: Duration::from_secs(1),
            max_backoff: Duration::from_secs(30),
            cooloff: Duration::from_secs(300),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Decision {
    Restart {
        after: Duration,
    },
    /// Too many crashes: the worker is considered failed for a while.
    CoolOff {
        after: Duration,
    },
}

impl Decision {
    pub fn after(self) -> Duration {
        match self {
            Decision::Restart { after } | Decision::CoolOff { after } => after,
        }
    }
}

pub struct Tracker {
    policy: Policy,
    recent: Vec<Instant>,
}

impl Tracker {
    pub fn new(policy: Policy) -> Self {
        Self {
            policy,
            recent: Vec::new(),
        }
    }

    pub fn on_panic(&mut self, now: Instant) -> Decision {
        let window = self.policy.window;
        self.recent
            .retain(|t| now.saturating_duration_since(*t) < window);
        self.recent.push(now);
        if self.recent.len() > self.policy.max_restarts {
            self.recent.clear();
            return Decision::CoolOff {
                after: self.policy.cooloff,
            };
        }
        let exp = (self.recent.len() as u32 - 1).min(16);
        Decision::Restart {
            after: (self.policy.backoff * 2u32.pow(exp)).min(self.policy.max_backoff),
        }
    }
}

fn panic_message(payload: &(dyn Any + Send)) -> String {
    payload
        .downcast_ref::<&str>()
        .map(|s| s.to_string())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "worker panicked".into())
}

/// Runs `work` on its own thread. A panic is caught and `work` is called again after the delay the
/// policy decides; `on_crash` hears about every crash (for status and logs). When `work` returns
/// normally the worker is done and the thread ends.
pub fn supervise(
    name: &'static str,
    policy: Policy,
    on_crash: impl Fn(&Decision, &str) + Send + 'static,
    work: impl Fn() + Send + 'static,
) -> JoinHandle<()> {
    std::thread::Builder::new()
        .name(name.into())
        .spawn(move || {
            let mut tracker = Tracker::new(policy);
            loop {
                match catch_unwind(AssertUnwindSafe(&work)) {
                    Ok(()) => return,
                    Err(payload) => {
                        let decision = tracker.on_panic(Instant::now());
                        on_crash(&decision, &panic_message(payload.as_ref()));
                        std::thread::sleep(decision.after());
                    }
                }
            }
        })
        .expect("spawn supervised thread")
}

#[cfg(test)]
mod tests;
