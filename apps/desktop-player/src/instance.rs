//! One player per PC. The backend allows one player per user: a second instance would make the
//! first one hear `replaced` and sit offline for 60 s. A named mutex tells the second launch it is
//! not the first.

use windows::Win32::Foundation::{ERROR_ALREADY_EXISTS, GetLastError};
use windows::Win32::System::Threading::CreateMutexW;
use windows::core::HSTRING;

/// `Local\` scopes the name to the Windows session, so two users on one PC do not block each other.
const NAME: &str = "Local\\premiere-ecoute-player";

fn is_taken(last_error: u32) -> bool {
    last_error == ERROR_ALREADY_EXISTS.0
}

fn claim(name: &str) -> bool {
    // SAFETY: the name is a valid, NUL-terminated wide string that outlives the call, and a null
    // security descriptor is allowed.
    let created = unsafe { CreateMutexW(None, false, &HSTRING::from(name)) };
    // SAFETY: reads the calling thread's last error, right after the call that set it.
    let last_error = unsafe { GetLastError() }.0;
    // The handle is never closed: the mutex must live as long as the process, and Windows frees it
    // when the process ends, however it ends. If the mutex cannot be created at all, start anyway:
    // a missing guard is better than a player that does not open.
    created.is_err() || !is_taken(last_error)
}

/// True when this process is the only player. Keep it called once, at startup.
pub fn first() -> bool {
    claim(NAME)
}

#[cfg(test)]
mod tests;
