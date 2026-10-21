//! Starting a commanded track, and checking that Spotify really played it.
//!
//! The desktop app is asked for a track with `spotify:track:<id>?autoplay=true`. Tested against a
//! real client, every track starts from 0:00 as asked, with one exception: the first track of the
//! album that is already loaded is not started, Spotify just goes on with what is loaded. That
//! case is recognised by what follows the command (the same track carrying on from where it was)
//! and repaired by walking back to the first track through the media session: pause, back to 0:00,
//! skip back until track 1. Spotify's own volume is muted meanwhile, because a skip starts the
//! track it lands on even when paused, and restored after.
//!
//! The repair relies on what the exception means: if Spotify resumed the loaded track, the track
//! asked for was the first of its album. It only runs when the track number is known.

use crate::player::{Backend, Playback, Snapshot, same_track};
use std::time::Duration;

/// Between two looks at Spotify.
const STEP: Duration = Duration::from_millis(100);
/// Looks, while waiting for Spotify to play: 5 s.
const LAUNCH_POLLS: u32 = 50;
/// Looks before a track that was playing and goes on is taken for a resume: 3 s. The new track may
/// take a moment to replace it.
const SETTLE_POLLS: u32 = 30;
/// Looks, for each step back and for the final start: 2 s.
const STEP_POLLS: u32 = 20;
/// Looks in a row that must show the same identity before it is believed: 1 s. Spotify updates the
/// title, the track number and the length one after the other, so for a moment a snapshot can show
/// the old title with the new length, or the reverse.
const STABLE_POLLS: u32 = 10;
/// Looks allowed for the identity to settle: 4 s.
const SETTLE_LOOKS: u32 = 40;
/// A track that plays from within this long of its start was started, not resumed.
const START_WINDOW: Duration = Duration::from_secs(3);
/// Spotify only skips back to the previous track within this long of the start of a track.
const SKIP_WINDOW: Duration = Duration::from_secs(2);
/// Steps back before giving up: more than any album has tracks.
const MAX_STEPS: u32 = 60;
/// Tries for a command: the second one starts from where the first left Spotify.
const ATTEMPTS: u32 = 2;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Verdict {
    /// A different track, or the same one from its beginning.
    Started,
    /// The same track carrying on from where it was.
    Resumed,
}

fn same(a: &Snapshot, b: &Snapshot) -> bool {
    same_track(
        &(a.title.clone(), a.artist.clone(), a.length),
        &(b.title.clone(), b.artist.clone(), b.length),
    )
}

/// `judge`, knowing which track of its album was asked for when it is known. If Spotify says
/// which track plays, that decides: another one is wrong whatever the position, the right one is
/// a start only from its beginning. Without a number on either side the position decides.
pub fn judge_expecting(before: &Snapshot, now: &Snapshot, expected: Option<u32>) -> Verdict {
    match (expected, now.track_number) {
        (Some(wanted), Some(playing)) if wanted != playing => Verdict::Resumed,
        _ => judge(before, now),
    }
}

/// What `now`, a playing snapshot taken after the command, says about it.
///
/// A track that is started plays from its beginning, whatever it is. One that plays from the
/// middle was not started: Spotify went back to where something was left (the loaded track, or
/// the album asked for at its last track and position).
pub fn judge(_before: &Snapshot, now: &Snapshot) -> Verdict {
    if now.position <= START_WINDOW {
        Verdict::Started
    } else {
        Verdict::Resumed
    }
}

fn playing(s: &Snapshot) -> bool {
    s.running && s.error.is_none() && s.playback == Playback::Playing
}

/// Why an attempt failed: whether trying again could help.
enum Failure {
    /// `resumed`: the command was seen to only resume what is loaded.
    Retry {
        message: String,
        resumed: bool,
    },
    Fatal(String),
}

/// Asks for `uri` and returns once the track plays from its beginning, or says why it does not.
/// `before` is what Spotify showed just before; `publish` sees every snapshot taken meanwhile, so
/// the window and the backend keep following; `sleep` waits between two looks.
///
/// Whatever state Spotify is in, the track is to start: a repair that fails is made once more from
/// where Spotify then is, knowing this time that the command only resumes what is loaded. Only a
/// Spotify that does not play at all, or whose track numbers cannot be read, is given up on at once.
#[cfg(test)]
pub fn start(
    backend: &mut impl Backend,
    uri: &str,
    before: &Snapshot,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<(), String> {
    start_expecting(backend, uri, None, before, publish, sleep)
}

/// `start`, for a track whose position in its album is known: that is then checked, whatever the
/// position it plays from, and Spotify is taken to the track when another one plays.
pub fn start_expecting(
    backend: &mut impl Backend,
    uri: &str,
    expected: Option<u32>,
    before: &Snapshot,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<(), String> {
    let mut before = before.clone();
    let mut why = String::new();
    let mut resumed = false;
    for attempt in 0..ATTEMPTS {
        match attempt_start(backend, uri, expected, &before, resumed, publish, sleep) {
            Ok(()) => return Ok(()),
            Err(Failure::Fatal(message)) => return Err(message),
            Err(Failure::Retry {
                message,
                resumed: seen,
            }) => {
                crate::log::warn(format!(
                    "play_uri attempt {} failed: {message}",
                    attempt + 1
                ));
                resumed |= seen;
                why = message;
                // Again from where Spotify is now, paused so nothing plays on meanwhile.
                let _ = backend.pause();
                if let Ok(now) = backend.snapshot() {
                    publish(&now);
                    before = now;
                }
            }
        }
    }
    Err(why)
}

fn attempt_start(
    backend: &mut impl Backend,
    uri: &str,
    expected: Option<u32>,
    before: &Snapshot,
    known_resume: bool,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<(), Failure> {
    backend.play_uri(uri).map_err(Failure::Fatal)?;
    let mut last = None;
    for look in 0..LAUNCH_POLLS {
        sleep(STEP);
        let s = backend.snapshot().map_err(Failure::Fatal)?;
        publish(&s);
        if !playing(&s) {
            continue;
        }
        // Paused before: playing now is the command taking effect. Playing before: the old track
        // may go on a moment, so what still is the old track proves nothing; a different track,
        // or a few seconds of the same, is the command taking effect.
        let conclusive =
            before.playback != Playback::Playing || !same(before, &s) || look >= SETTLE_POLLS;
        if !conclusive {
            continue;
        }
        // Already known to only resume what is loaded: the position says nothing (the first
        // attempt left it at the start of the track), so there is nothing to judge.
        if known_resume {
            last = Some(s);
            break;
        }
        // Spotify updates its properties one after the other while it switches: what is judged is
        // a state that has held still, not the first one seen.
        let s = settle(backend, s, publish, sleep).map_err(|message| Failure::Retry {
            message,
            resumed: false,
        })?;
        let verdict = judge_expecting(before, &s, expected);
        crate::log::info(format!(
            "play_uri (track {expected:?}): before {:?} {}/{} s {:?}, now {:?} (track {:?}) {}/{} s -> {verdict:?}",
            before.title,
            before.position.as_secs(),
            before.length.as_secs(),
            before.playback,
            s.title,
            s.track_number,
            s.position.as_secs(),
            s.length.as_secs()
        ));
        match verdict {
            Verdict::Started => return Ok(()),
            Verdict::Resumed => {
                last = Some(s);
                break;
            }
        }
    }
    let Some(resumed) = last else {
        return Err(Failure::Fatal(
            "Spotify did not start playing the track".into(),
        ));
    };
    repair(
        backend,
        &resumed,
        expected.unwrap_or(1),
        before,
        publish,
        sleep,
    )
}

/// Waits for the identity of the playing track (title, artist, length and track number) to hold
/// still for `STABLE_POLLS` looks in a row, and returns that snapshot, published.
fn settle(
    backend: &mut impl Backend,
    first: Snapshot,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<Snapshot, String> {
    let mut seen = first;
    let mut steady = 1;
    for _ in 0..SETTLE_LOOKS {
        if steady >= STABLE_POLLS {
            return Ok(seen);
        }
        sleep(STEP);
        let next = backend.snapshot()?;
        publish(&next);
        if playing(&next) && same(&next, &seen) && next.track_number == seen.track_number {
            steady += 1;
        } else {
            steady = 1;
        }
        seen = next;
    }
    Err("the track Spotify started never settled".into())
}

/// Spotify resumed the loaded track: go back to the first track of its album.
fn repair(
    backend: &mut impl Backend,
    resumed: &Snapshot,
    target: u32,
    before: &Snapshot,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<(), Failure> {
    let Some(number) = resumed.track_number else {
        return Err(Failure::Fatal(
            "Spotify resumed another track and its number is unknown".into(),
        ));
    };
    crate::log::info(format!(
        "Spotify is on {:?} (track {number}) instead of the commanded track {target}: going to track {target}",
        resumed.title
    ));
    let volume = resumed.volume.or(before.volume);
    if volume.is_some() {
        backend.set_volume(0.0).map_err(|message| Failure::Retry {
            message,
            resumed: true,
        })?;
    }
    let result = go_to(backend, target, publish, sleep);
    match &result {
        Ok(()) => crate::log::info(format!("on track {target}, from its beginning")),
        Err(message) => crate::log::warn(format!("could not get to track {target}: {message}")),
    }
    if let Some(volume) = volume {
        // Whatever happened, Spotify is never left muted.
        let _ = backend.set_volume(volume);
    }
    result.map_err(|message| Failure::Retry {
        message,
        resumed: true,
    })
}

fn go_to(
    backend: &mut impl Backend,
    target: u32,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
) -> Result<(), String> {
    backend.pause()?;
    backend.seek(Duration::ZERO)?;
    // Each step looks at where Spotify really is: it may have moved on by itself (a track resumed
    // in its last second goes on to the next), so a number read earlier is not to be trusted.
    let mut steps = 0;
    loop {
        sleep(STEP);
        let now = backend.snapshot()?;
        publish(&now);
        let Some(number) = now.track_number else {
            return Err("Spotify's track number is unknown".into());
        };
        if number == target {
            break;
        }
        steps += 1;
        if steps > MAX_STEPS {
            return Err(format!("Spotify did not get to track {target}"));
        }
        if number > target {
            // A skip back only goes to the previous track within the first seconds of a track.
            if now.position > SKIP_WINDOW {
                backend.seek(Duration::ZERO)?;
            }
            backend.previous()?;
        } else {
            backend.next()?;
        }
        wait_for(backend, publish, sleep, |s| s.track_number != Some(number))
            .map_err(|_| format!("Spotify did not move from track {number}"))?;
    }
    // On the track: from its beginning, playing.
    let now = backend.snapshot()?;
    if now.position > START_WINDOW {
        backend.seek(Duration::ZERO)?;
    }
    if !playing(&now) || now.position > START_WINDOW {
        backend.play()?;
    }
    wait_for(backend, publish, sleep, |s| {
        playing(s) && s.position <= START_WINDOW
    })
    .map_err(|_| format!("Spotify did not play track {target} from its beginning"))
}

fn wait_for(
    backend: &mut impl Backend,
    publish: &mut dyn FnMut(&Snapshot),
    sleep: &dyn Fn(Duration),
    done: impl Fn(&Snapshot) -> bool,
) -> Result<(), ()> {
    for _ in 0..STEP_POLLS {
        sleep(STEP);
        let s = backend.snapshot().map_err(|_| ())?;
        publish(&s);
        if done(&s) {
            return Ok(());
        }
    }
    Err(())
}

#[cfg(test)]
mod tests;
