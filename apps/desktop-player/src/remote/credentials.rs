//! Where the refresh token lives. On Windows: the Credential Manager, protected for the current
//! user. The access token is never stored.

#[cfg(any(test, not(windows)))]
use std::sync::Mutex;

pub trait CredentialStore {
    fn load(&self) -> Result<Option<String>, String>;
    fn save(&self, refresh_token: &str) -> Result<(), String>;
    fn delete(&self) -> Result<(), String>;
}

/// For tests, and for platforms without a credential manager.
#[cfg(any(test, not(windows)))]
#[derive(Default)]
pub struct MemoryStore {
    pub value: Mutex<Option<String>>,
    /// When set, `save` fails, to simulate a locked-down or broken store.
    pub fail_saves: Mutex<bool>,
}

#[cfg(any(test, not(windows)))]
impl CredentialStore for MemoryStore {
    fn load(&self) -> Result<Option<String>, String> {
        Ok(self.value.lock().unwrap().clone())
    }

    fn save(&self, refresh_token: &str) -> Result<(), String> {
        if *self.fail_saves.lock().unwrap() {
            return Err("the store is not writable".into());
        }
        *self.value.lock().unwrap() = Some(refresh_token.to_string());
        Ok(())
    }

    fn delete(&self) -> Result<(), String> {
        *self.value.lock().unwrap() = None;
        Ok(())
    }
}

#[cfg(windows)]
pub use windows_store::WindowsStore;

#[cfg(windows)]
mod windows_store {
    use super::CredentialStore;
    use windows::Win32::Foundation::ERROR_NOT_FOUND;
    use windows::Win32::Security::Credentials::{
        CRED_PERSIST_LOCAL_MACHINE, CRED_TYPE_GENERIC, CREDENTIALW, CredDeleteW, CredFree, CredReadW, CredWriteW,
    };
    use windows::core::{PCWSTR, PWSTR};

    /// One credential per backend address, so a development server and production never collide.
    pub struct WindowsStore {
        target: Vec<u16>,
    }

    impl WindowsStore {
        pub fn for_server(base_url: &str) -> Self {
            let name = format!("premiere-ecoute-player:{}", base_url.trim_end_matches('/'));
            Self { target: name.encode_utf16().chain(std::iter::once(0)).collect() }
        }
    }

    fn not_found(e: &windows::core::Error) -> bool {
        e.code() == windows::core::HRESULT::from_win32(ERROR_NOT_FOUND.0)
    }

    impl CredentialStore for WindowsStore {
        fn load(&self) -> Result<Option<String>, String> {
            unsafe {
                let mut cred: *mut CREDENTIALW = std::ptr::null_mut();
                match CredReadW(PCWSTR(self.target.as_ptr()), CRED_TYPE_GENERIC, None, &mut cred) {
                    Ok(()) => {
                        let c = &*cred;
                        let bytes = std::slice::from_raw_parts(c.CredentialBlob, c.CredentialBlobSize as usize);
                        let value = String::from_utf8(bytes.to_vec()).map_err(|e| e.to_string());
                        CredFree(cred as *const _);
                        value.map(Some)
                    }
                    Err(e) if not_found(&e) => Ok(None),
                    Err(e) => Err(e.message()),
                }
            }
        }

        fn save(&self, refresh_token: &str) -> Result<(), String> {
            let mut blob = refresh_token.as_bytes().to_vec();
            let mut target = self.target.clone();
            let cred = CREDENTIALW {
                Type: CRED_TYPE_GENERIC,
                TargetName: PWSTR(target.as_mut_ptr()),
                CredentialBlobSize: blob.len() as u32,
                CredentialBlob: blob.as_mut_ptr(),
                Persist: CRED_PERSIST_LOCAL_MACHINE,
                ..Default::default()
            };
            unsafe { CredWriteW(&cred, 0) }.map_err(|e| e.message())
        }

        fn delete(&self) -> Result<(), String> {
            match unsafe { CredDeleteW(PCWSTR(self.target.as_ptr()), CRED_TYPE_GENERIC, None) } {
                Ok(()) => Ok(()),
                Err(e) if not_found(&e) => Ok(()),
                Err(e) => Err(e.message()),
            }
        }
    }

}

#[cfg(all(test, windows))]
mod tests;
