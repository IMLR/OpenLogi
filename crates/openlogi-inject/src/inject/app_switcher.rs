//! The system application switcher, walked by a run of steps the way Logi
//! Options+ "Navigate between apps" walks it with the thumb wheel.
//!
//! The first step holds the switcher modifier (Cmd on macOS, Alt elsewhere)
//! and taps Tab. Each further step replaces the held chord with the same
//! modifier, which taps Tab again without lifting the modifier, so the
//! switcher stays open and its highlight moves; Shift follows the step's
//! direction. Once the steps pause, the held chord is dropped: the modifier
//! comes up and the switcher activates the highlighted application.

use std::sync::{Mutex, PoisonError};
use std::thread;
use std::time::{Duration, Instant};

use openlogi_core::binding::HeldKeys;

use super::{HeldChord, parse_shortcut, press_hold};

/// Pause after the last step that releases the modifier.
const IDLE_RELEASE: Duration = Duration::from_millis(700);
/// Longest one run may hold the modifier, so a run that never pauses cannot
/// pin it down.
const MAX_HOLD: Duration = Duration::from_secs(20);
/// How often the release watcher looks for the pause.
const POLL: Duration = Duration::from_millis(20);

/// The run in progress: the held chord and when it started and last stepped.
struct Run {
    held: HeldChord,
    started: Instant,
    last_step: Instant,
}

/// Lock order: `RUN` before the held-output lock that [`press_hold`],
/// [`HeldChord::replace`], and dropping a [`HeldChord`] take.
static RUN: Mutex<Option<Run>> = Mutex::new(None);

/// Step the application switcher one application forward or back.
pub(super) fn step(forward: bool) {
    let combo = parse_shortcut(chord(forward));
    let mut run = RUN.lock().unwrap_or_else(PoisonError::into_inner);
    let now = Instant::now();
    if let Some(active) = run.as_mut() {
        active.held.replace(&combo, HeldKeys::ModifiersOnly);
        active.last_step = now;
        return;
    }
    *run = Some(Run {
        held: press_hold(&combo, HeldKeys::ModifiersOnly),
        started: now,
        last_step: now,
    });
    drop(run);
    spawn_release_watcher();
}

/// Release the modifier once the run pauses, from a thread of its own so the
/// release does not wait for another step.
fn spawn_release_watcher() {
    let spawned = thread::Builder::new()
        .name("openlogi-app-switcher".into())
        .spawn(|| {
            loop {
                thread::sleep(POLL);
                let mut run = RUN.lock().unwrap_or_else(PoisonError::into_inner);
                let Some(active) = run.as_ref() else {
                    return;
                };
                if active.last_step.elapsed() >= IDLE_RELEASE || active.started.elapsed() >= MAX_HOLD
                {
                    // Dropping the held chord releases the modifier.
                    *run = None;
                    return;
                }
            }
        });
    if let Err(error) = spawned {
        tracing::warn!(%error, "application switcher release watcher did not start; releasing now");
        *RUN.lock().unwrap_or_else(PoisonError::into_inner) = None;
    }
}

/// The switcher chord for one step on this platform.
fn chord(forward: bool) -> &'static str {
    match (cfg!(target_os = "macos"), forward) {
        (true, true) => "Cmd+Tab",
        (true, false) => "Cmd+Shift+Tab",
        (false, true) => "Alt+Tab",
        (false, false) => "Alt+Shift+Tab",
    }
}
