//! Spotify's own volume (the per-app slider in the Windows volume mixer),
//! via the Core Audio session API. SMTC has no volume control.

use windows::Win32::Foundation::{CloseHandle, MAX_PATH};
use windows::Win32::Media::Audio::{
    IAudioSessionControl2, IAudioSessionManager2, IMMDeviceEnumerator, ISimpleAudioVolume,
    MMDeviceEnumerator, eMultimedia, eRender,
};
use windows::Win32::System::Com::{
    CLSCTX_ALL, COINIT_MULTITHREADED, CoCreateInstance, CoInitializeEx,
};
use windows::Win32::System::Threading::{
    OpenProcess, PROCESS_NAME_WIN32, PROCESS_QUERY_LIMITED_INFORMATION, QueryFullProcessImageNameW,
};
use windows::core::{Interface, PWSTR};

fn err(e: windows::core::Error) -> String {
    e.message()
}

fn is_spotify(pid: u32) -> bool {
    // SAFETY: `buf` and `len` outlive the calls and `len` is its capacity in UTF-16 units. The process
    // handle is closed exactly once, after its last use.
    unsafe {
        let Ok(process) = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid) else {
            return false;
        };
        let mut buf = [0u16; MAX_PATH as usize];
        let mut len = buf.len() as u32;
        let ok = QueryFullProcessImageNameW(
            process,
            PROCESS_NAME_WIN32,
            PWSTR(buf.as_mut_ptr()),
            &mut len,
        )
        .is_ok();
        let _ = CloseHandle(process);
        ok && String::from_utf16_lossy(&buf[..len as usize])
            .to_lowercase()
            .ends_with("\\spotify.exe")
    }
}

/// Spotify's audio session and the process that owns it, if it currently has one.
fn spotify_session() -> Result<Option<(IAudioSessionControl2, u32)>, String> {
    // SAFETY: plain COM calls on interfaces owned by this function; each returned interface is
    // reference-counted by the `windows` crate and released on drop.
    unsafe {
        // Ok to call repeatedly on the same thread; returns S_FALSE.
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED);
        let enumerator: IMMDeviceEnumerator =
            CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL).map_err(err)?;
        let device = enumerator
            .GetDefaultAudioEndpoint(eRender, eMultimedia)
            .map_err(err)?;
        let manager: IAudioSessionManager2 = device.Activate(CLSCTX_ALL, None).map_err(err)?;
        let sessions = manager.GetSessionEnumerator().map_err(err)?;
        for i in 0..sessions.GetCount().map_err(err)? {
            let control = sessions.GetSession(i).map_err(err)?;
            let control2: IAudioSessionControl2 = control.cast().map_err(err)?;
            let pid = control2.GetProcessId().map_err(err)?;
            if is_spotify(pid) {
                return Ok(Some((control2, pid)));
            }
        }
        Ok(None)
    }
}

/// The process that plays Spotify's sound, once Spotify has an audio session.
pub fn spotify_pid() -> Result<Option<u32>, String> {
    Ok(spotify_session()?.map(|(_, pid)| pid))
}

/// Finds Spotify's audio session volume control, if it currently has one.
fn spotify_volume() -> Result<Option<ISimpleAudioVolume>, String> {
    match spotify_session()? {
        Some((control, _)) => Ok(Some(control.cast().map_err(err)?)),
        None => Ok(None),
    }
}

pub fn get() -> Result<Option<f32>, String> {
    match spotify_volume()? {
        // SAFETY: `v` is a live COM interface owned here.
        Some(v) => Ok(Some(unsafe { v.GetMasterVolume() }.map_err(err)?)),
        None => Ok(None),
    }
}

pub fn set(volume: f32) -> Result<(), String> {
    let v = spotify_volume()?.ok_or("Spotify has no audio session yet (play something first)")?;
    // SAFETY: `v` is a live COM interface; a null event context is allowed.
    unsafe { v.SetMasterVolume(volume.clamp(0.0, 1.0), std::ptr::null()) }.map_err(err)
}
