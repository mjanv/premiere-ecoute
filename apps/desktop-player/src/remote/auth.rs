//! Access tokens for the socket, and the sign-in that creates them.
//!
//! The backend rotates the refresh token on every refresh and revokes the old one at once. So the
//! new refresh token is kept in memory first and written to the store second: a failing store
//! cannot lose the credential while the app runs, and the write is retried until it succeeds.

use super::credentials::CredentialStore;
use super::oauth::{self, AuthError, Http, Tokens};
use std::time::{Duration, Instant};

/// Refresh when the access token has less than this left.
const REFRESH_MARGIN: Duration = Duration::from_secs(60);

pub trait Browser {
    fn open(&self, url: &str) -> Result<(), String>;
}

pub struct Auth {
    http: Box<dyn Http>,
    store: Box<dyn CredentialStore>,
    base: String,
    loaded: bool,
    refresh_token: Option<String>,
    access: Option<(String, Instant)>,
    /// The newest refresh token is in memory but not yet in the store.
    unsaved: bool,
}

impl Auth {
    pub fn new(http: Box<dyn Http>, store: Box<dyn CredentialStore>, base: String) -> Self {
        Self {
            http,
            store,
            base,
            loaded: false,
            refresh_token: None,
            access: None,
            unsaved: false,
        }
    }

    fn load(&mut self) -> Result<(), AuthError> {
        if !self.loaded {
            self.refresh_token = self
                .store
                .load()
                .map_err(|e| AuthError::Transient(format!("cannot read the saved sign-in: {e}")))?;
            self.loaded = true;
        }
        Ok(())
    }

    fn try_save(&mut self) {
        if let (true, Some(token)) = (self.unsaved, self.refresh_token.as_deref()) {
            self.unsaved = self.store.save(token).is_err();
        }
    }

    fn adopt_tokens(&mut self, tokens: Tokens, now: Instant) -> String {
        self.refresh_token = Some(tokens.refresh);
        self.loaded = true;
        self.unsaved = true;
        self.try_save();
        self.access = Some((tokens.access.clone(), now + tokens.expires_in));
        tokens.access
    }

    /// A valid access token, refreshing when needed.
    pub fn access_token(&mut self, now: Instant) -> Result<String, AuthError> {
        self.load()?;
        self.try_save();
        if let Some((token, expires)) = &self.access
            && *expires > now + REFRESH_MARGIN
        {
            return Ok(token.clone());
        }
        let refresh = self.refresh_token.clone().ok_or(AuthError::NotEnrolled)?;
        match oauth::refresh(self.http.as_ref(), &self.base, &refresh) {
            Ok(tokens) => Ok(self.adopt_tokens(tokens, now)),
            Err(AuthError::Unauthorized(why)) => {
                // The credential is dead: forget it, the user has to sign in again.
                self.clear();
                Err(AuthError::Unauthorized(why))
            }
            Err(other) => Err(other),
        }
    }

    /// The socket refused the access token: refresh on the next call even if it looks valid.
    pub fn invalidate_access(&mut self) {
        self.access = None;
    }

    fn clear(&mut self) {
        self.access = None;
        self.refresh_token = None;
        self.unsaved = false;
        let _ = self.store.delete();
    }

    /// Browser sign-in: PKCE, loopback redirect, consent, code exchange.
    pub fn sign_in(
        &mut self,
        browser: &dyn Browser,
        timeout: Duration,
        now: Instant,
    ) -> Result<(), AuthError> {
        let (listener, port) = oauth::bind_loopback()?;
        let (verifier, state) = (oauth::code_verifier(), oauth::random_state());
        let url =
            oauth::authorize_url(&self.base, port, &state, &oauth::code_challenge(&verifier))?;
        browser
            .open(&url)
            .map_err(|e| AuthError::Transient(format!("cannot open the browser: {e}")))?;
        let code = oauth::wait_for_callback(&listener, &state, timeout)?;
        let tokens = oauth::exchange_code(self.http.as_ref(), &self.base, port, &code, &verifier)?;
        self.adopt_tokens(tokens, now);
        Ok(())
    }

    /// Signs out: tells the backend (best effort) and forgets everything locally.
    pub fn forget(&mut self) {
        if self.load().is_ok()
            && let Some(token) = &self.refresh_token
        {
            oauth::revoke(self.http.as_ref(), &self.base, token);
        }
        self.clear();
        self.loaded = true;
    }

    /// The credential is dead because the backend said so on the socket (`disconnect: revoked`).
    pub fn discard(&mut self) {
        self.clear();
        self.loaded = true;
    }
}

#[cfg(test)]
mod tests;
