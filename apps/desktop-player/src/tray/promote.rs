//! Keeps the tray icon out of the "^" overflow. Windows 11 hides every new tray icon there, and a
//! status light behind a click is no status light. There is no API for it: Explorer records one
//! `IsPromoted` value per icon under `HKCU\Control Panel\NotifyIconSettings`, and writing it moves
//! the icon to the visible tray at once. Undocumented, so it is best effort: on any failure the
//! icon simply stays where Windows put it.
//!
//! The value is only written when it does not exist yet. If the user later hides the icon, that
//! choice is theirs.

use std::time::Duration;
use windows::Win32::System::Registry::{
    HKEY, HKEY_CURRENT_USER, KEY_READ, KEY_SET_VALUE, REG_DWORD, RRF_RT_REG_DWORD, RRF_RT_REG_SZ,
    RegCloseKey, RegEnumKeyExW, RegGetValueW, RegOpenKeyExW, RegSetValueExW,
};
use windows::core::{HSTRING, PWSTR};

const SETTINGS: &str = "Control Panel\\NotifyIconSettings";
/// The id of our icon, see `tray::ICON_ID`.
const ICON_UID: u32 = super::ICON_ID;
/// Explorer creates the entry a moment after the icon is added.
const ATTEMPTS: u32 = 20;
const WAIT: Duration = Duration::from_millis(500);

fn should_promote(current: Option<u32>) -> bool {
    current.is_none()
}

fn normal(path: &str) -> String {
    path.strip_prefix(r"\\?\").unwrap_or(path).to_lowercase()
}

fn same_exe(recorded: &str, ours: &str) -> bool {
    !recorded.is_empty() && normal(recorded) == normal(ours)
}

struct Key(HKEY);

impl Key {
    fn open(
        parent: HKEY,
        name: &str,
        access: windows::Win32::System::Registry::REG_SAM_FLAGS,
    ) -> Option<Self> {
        let mut key = HKEY::default();
        // SAFETY: `key` receives the opened handle; the name is a valid wide string.
        let status = unsafe { RegOpenKeyExW(parent, &HSTRING::from(name), None, access, &mut key) };
        status.is_ok().then_some(Self(key))
    }

    fn string(&self, name: &str) -> Option<String> {
        let mut buffer = [0u16; 1024];
        let mut bytes = std::mem::size_of_val(&buffer) as u32;
        // SAFETY: `buffer` has room for `bytes` bytes, and `bytes` tells the API so.
        let status = unsafe {
            RegGetValueW(
                self.0,
                None,
                &HSTRING::from(name),
                RRF_RT_REG_SZ,
                None,
                Some(buffer.as_mut_ptr().cast()),
                Some(&mut bytes),
            )
        };
        status.is_ok().then(|| {
            let units = (bytes as usize / 2).saturating_sub(1);
            String::from_utf16_lossy(&buffer[..units.min(buffer.len())])
        })
    }

    fn dword(&self, name: &str) -> Option<u32> {
        let mut value = 0u32;
        let mut bytes = 4u32;
        // SAFETY: `value` is the 4 bytes of a DWORD, and `bytes` says so.
        let status = unsafe {
            RegGetValueW(
                self.0,
                None,
                &HSTRING::from(name),
                RRF_RT_REG_DWORD,
                None,
                Some((&mut value as *mut u32).cast()),
                Some(&mut bytes),
            )
        };
        status.is_ok().then_some(value)
    }

    fn set_dword(&self, name: &str, value: u32) -> bool {
        // SAFETY: the data is the 4 bytes of a DWORD, matching `REG_DWORD`.
        unsafe {
            RegSetValueExW(
                self.0,
                &HSTRING::from(name),
                None,
                REG_DWORD,
                Some(&value.to_le_bytes()),
            )
        }
        .is_ok()
    }
}

impl Drop for Key {
    fn drop(&mut self) {
        // SAFETY: the handle was opened by `Key::open` and is closed once.
        let _ = unsafe { RegCloseKey(self.0) };
    }
}

fn subkeys(settings: &Key) -> Vec<String> {
    let mut names = Vec::new();
    for index in 0.. {
        let mut name = [0u16; 256];
        let mut len = name.len() as u32;
        // SAFETY: `name` has room for `len` characters, and `len` tells the API so.
        let status = unsafe {
            RegEnumKeyExW(
                settings.0,
                index,
                Some(PWSTR(name.as_mut_ptr())),
                &mut len,
                None,
                None,
                None,
                None,
            )
        };
        if status.is_err() {
            break;
        }
        names.push(String::from_utf16_lossy(&name[..len as usize]));
    }
    names
}

/// Looks for this exe's icon entry. `Some(())` once it exists, whether or not it needed a write.
fn promote_once(exe: &str) -> Option<()> {
    let settings = Key::open(HKEY_CURRENT_USER, SETTINGS, KEY_READ)?;
    for name in subkeys(&settings) {
        let Some(entry) = Key::open(settings.0, &name, KEY_READ | KEY_SET_VALUE) else {
            continue;
        };
        let ours = entry
            .string("ExecutablePath")
            .is_some_and(|path| same_exe(&path, exe))
            && entry.dword("UID") == Some(ICON_UID);
        if !ours {
            continue;
        }
        if should_promote(entry.dword("IsPromoted")) {
            entry.set_dword("IsPromoted", 1);
        }
        return Some(());
    }
    None
}

/// Waits for Explorer to record the icon, then promotes it. Run it on its own thread.
pub fn run() {
    let Ok(exe) = std::env::current_exe() else {
        return;
    };
    let exe = exe.to_string_lossy().into_owned();
    for _ in 0..ATTEMPTS {
        if promote_once(&exe).is_some() {
            return;
        }
        std::thread::sleep(WAIT);
    }
}

#[cfg(test)]
mod tests;
