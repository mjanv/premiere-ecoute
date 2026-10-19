use super::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

fn policy() -> Policy {
    Policy {
        max_restarts: 3,
        window: Duration::from_secs(60),
        backoff: Duration::from_secs(1),
        max_backoff: Duration::from_secs(4),
        cooloff: Duration::from_secs(300),
    }
}

#[test]
fn restarts_back_off_exponentially_up_to_the_cap() {
    let mut t = Tracker::new(policy());
    let now = Instant::now();
    assert_eq!(
        t.on_panic(now),
        Decision::Restart {
            after: Duration::from_secs(1)
        }
    );
    assert_eq!(
        t.on_panic(now),
        Decision::Restart {
            after: Duration::from_secs(2)
        }
    );
    assert_eq!(
        t.on_panic(now),
        Decision::Restart {
            after: Duration::from_secs(4)
        }
    );
}

#[test]
fn too_many_crashes_in_the_window_mean_a_cool_off_then_a_fresh_start() {
    let mut t = Tracker::new(policy());
    let now = Instant::now();
    for _ in 0..3 {
        t.on_panic(now);
    }
    assert_eq!(
        t.on_panic(now),
        Decision::CoolOff {
            after: Duration::from_secs(300)
        }
    );
    assert_eq!(
        t.on_panic(now),
        Decision::Restart {
            after: Duration::from_secs(1)
        }
    );
}

#[test]
fn crashes_outside_the_window_are_forgotten() {
    let mut t = Tracker::new(policy());
    let start = Instant::now();
    for _ in 0..3 {
        t.on_panic(start);
    }
    let later = start + Duration::from_secs(61);
    assert_eq!(
        t.on_panic(later),
        Decision::Restart {
            after: Duration::from_secs(1)
        }
    );
}

#[test]
fn a_panicking_worker_is_restarted_until_it_finishes() {
    let fast = Policy {
        backoff: Duration::from_millis(1),
        max_backoff: Duration::from_millis(2),
        ..policy()
    };
    let runs = Arc::new(AtomicUsize::new(0));
    let crashes = Arc::new(Mutex::new(Vec::new()));
    let handle = {
        let (runs, crashes) = (runs.clone(), crashes.clone());
        supervise(
            "test-worker",
            fast,
            move |_, message| crashes.lock().unwrap().push(message.to_string()),
            move || {
                if runs.fetch_add(1, Ordering::SeqCst) < 2 {
                    panic!("boom");
                }
            },
        )
    };
    handle.join().unwrap();
    assert_eq!(runs.load(Ordering::SeqCst), 3);
    assert_eq!(*crashes.lock().unwrap(), ["boom", "boom"]);
}
