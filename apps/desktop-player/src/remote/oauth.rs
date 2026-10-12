//! OAuth 2.1 authorization code with PKCE (S256) against the backend, as described in
//! `docs/guides/desktop-player.md`: public client, loopback redirect, scope `player`.
//! Everything here is pure or goes through the `Http` trait, so it is testable without a server.

use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::net::{Ipv4Addr, SocketAddr, TcpListener};
use std::time::{Duration, Instant};
use url::Url;

/// Public client of the player (no secret), from the backend guide.
pub const CLIENT_ID: &str = "6c1d8f0e-3a52-4b7e-9e41-2f5a7c9d8b13";
pub const SCOPE: &str = "player";
const UNRESERVED: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AuthError {
    /// Nothing stored: the user has not signed in on this PC.
    NotEnrolled,
    /// The credential is dead (`invalid_grant`, revoked): ask the user to sign in again.
    Unauthorized(String),
    /// The user said no on the consent screen.
    Denied,
    /// The user never came back from the browser.
    TimedOut,
    /// Network or server trouble: try again later.
    Transient(String),
}

impl std::fmt::Display for AuthError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AuthError::NotEnrolled => write!(f, "not signed in"),
            AuthError::Unauthorized(why) => write!(f, "sign in again ({why})"),
            AuthError::Denied => write!(f, "sign in was cancelled"),
            AuthError::TimedOut => write!(f, "sign in timed out"),
            AuthError::Transient(why) => write!(f, "{why}"),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Tokens {
    pub access: String,
    pub refresh: String,
    pub expires_in: Duration,
}

pub struct HttpResponse {
    pub status: u16,
    pub body: String,
}

pub trait Http {
    fn post_form(&self, url: &str, form: &[(&str, &str)]) -> Result<HttpResponse, String>;
}

// ---- PKCE ----------------------------------------------------------------------------------

/// 64 random characters of `[A-Za-z0-9-._~]`, drawn without modulo bias.
pub fn code_verifier() -> String {
    let mut out = String::with_capacity(64);
    let mut buf = [0u8; 128];
    while out.len() < 64 {
        getrandom::fill(&mut buf).expect("the OS random generator is available");
        for b in buf {
            // 198 = 3 * 66, the largest multiple of the alphabet size below 256.
            if b < 198 && out.len() < 64 {
                out.push(UNRESERVED[b as usize % UNRESERVED.len()] as char);
            }
        }
    }
    out
}

pub fn code_challenge(verifier: &str) -> String {
    URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()))
}

pub fn random_state() -> String {
    let mut bytes = [0u8; 24];
    getrandom::fill(&mut bytes).expect("the OS random generator is available");
    URL_SAFE_NO_PAD.encode(bytes)
}

pub fn redirect_uri(port: u16) -> String {
    format!("http://127.0.0.1:{port}/cb")
}

pub fn authorize_url(base: &str, port: u16, state: &str, challenge: &str) -> Result<String, AuthError> {
    let mut url = Url::parse(base).map_err(|e| AuthError::Transient(format!("bad server address: {e}")))?;
    url.set_path("/oauth/authorize");
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("client_id", CLIENT_ID)
        .append_pair("redirect_uri", &redirect_uri(port))
        .append_pair("scope", SCOPE)
        .append_pair("state", state)
        .append_pair("code_challenge", challenge)
        .append_pair("code_challenge_method", "S256");
    Ok(url.to_string())
}

// ---- loopback callback ---------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Callback {
    Code(String),
    Denied,
    /// Not our request (wrong path, wrong or missing state): ignore it and keep waiting.
    Ignore,
}

fn same(a: &str, b: &str) -> bool {
    // Constant time over equal lengths; the state is not secret from us, but there is no reason to leak it.
    a.len() == b.len() && a.bytes().zip(b.bytes()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// Interprets the first line of an HTTP request (`GET /cb?code=..&state=.. HTTP/1.1`).
pub fn parse_callback(request_line: &str, expected_state: &str) -> Callback {
    let mut parts = request_line.split_whitespace();
    if parts.next() != Some("GET") {
        return Callback::Ignore;
    }
    let Some(target) = parts.next() else { return Callback::Ignore };
    let Ok(url) = Url::parse(&format!("http://127.0.0.1{target}")) else { return Callback::Ignore };
    if url.path() != "/cb" {
        return Callback::Ignore;
    }
    let q = |name: &str| url.query_pairs().find(|(k, _)| k == name).map(|(_, v)| v.into_owned());
    // The state is checked before anything else.
    if !q("state").is_some_and(|s| same(&s, expected_state)) {
        return Callback::Ignore;
    }
    match (q("code"), q("error")) {
        (Some(code), None) if !code.is_empty() => Callback::Code(code),
        (_, Some(_)) => Callback::Denied,
        _ => Callback::Ignore,
    }
}

const PAGE: &str = "<!doctype html><meta charset=utf-8><title>Player</title><body style=\"font-family:sans-serif;background:#15171a;color:#eee;display:grid;place-items:center;height:100vh\"><p>You can close this tab and go back to the player.</p>";
const MAX_REQUEST: usize = 8 * 1024;

fn respond(stream: &mut std::net::TcpStream, status: &str, body: &str) {
    let _ = write!(stream, "HTTP/1.1 {status}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len());
}

/// Waits for the browser to come back to `127.0.0.1:<port>/cb`. Accepts the first valid request,
/// ignores everything else, and gives up at `timeout`.
pub fn wait_for_callback(listener: &TcpListener, state: &str, timeout: Duration) -> Result<String, AuthError> {
    listener.set_nonblocking(true).map_err(|e| AuthError::Transient(e.to_string()))?;
    let deadline = Instant::now() + timeout;
    loop {
        match listener.accept() {
            Ok((mut stream, _)) => {
                let _ = stream.set_nonblocking(false);
                let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
                let mut buf = Vec::new();
                let mut chunk = [0u8; 1024];
                while buf.len() < MAX_REQUEST && !buf.windows(2).any(|w| w == b"\r\n") {
                    match stream.read(&mut chunk) {
                        Ok(0) | Err(_) => break,
                        Ok(n) => buf.extend_from_slice(&chunk[..n]),
                    }
                }
                let line = String::from_utf8_lossy(&buf).lines().next().unwrap_or("").to_string();
                match parse_callback(&line, state) {
                    Callback::Code(code) => {
                        respond(&mut stream, "200 OK", PAGE);
                        return Ok(code);
                    }
                    Callback::Denied => {
                        respond(&mut stream, "200 OK", PAGE);
                        return Err(AuthError::Denied);
                    }
                    Callback::Ignore => respond(&mut stream, "404 Not Found", ""),
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                if Instant::now() >= deadline {
                    return Err(AuthError::TimedOut);
                }
                std::thread::sleep(Duration::from_millis(50));
            }
            Err(e) => return Err(AuthError::Transient(e.to_string())),
        }
    }
}

pub fn bind_loopback() -> Result<(TcpListener, u16), AuthError> {
    let listener = TcpListener::bind(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))).map_err(|e| AuthError::Transient(e.to_string()))?;
    let port = listener.local_addr().map_err(|e| AuthError::Transient(e.to_string()))?.port();
    Ok((listener, port))
}

// ---- token endpoint ------------------------------------------------------------------------

fn endpoint(base: &str, path: &str) -> Result<String, AuthError> {
    let mut url = Url::parse(base).map_err(|e| AuthError::Transient(format!("bad server address: {e}")))?;
    url.set_path(path);
    Ok(url.to_string())
}

pub fn parse_token_response(status: u16, body: &str) -> Result<Tokens, AuthError> {
    let json: Value = serde_json::from_str(body).unwrap_or(Value::Null);
    match status {
        200 => {
            let text = |k: &str| json[k].as_str().filter(|s| !s.is_empty()).map(str::to_string);
            match (text("access_token"), text("refresh_token"), json["expires_in"].as_u64()) {
                (Some(access), Some(refresh), Some(secs)) => Ok(Tokens { access, refresh, expires_in: Duration::from_secs(secs) }),
                _ => Err(AuthError::Transient("the server answered without tokens".into())),
            }
        }
        400..=499 => {
            let error = json["error"].as_str().unwrap_or("rejected");
            let detail = json["error_description"].as_str().unwrap_or(error);
            match error {
                "invalid_grant" | "invalid_client" | "unauthorized_client" | "invalid_scope" => Err(AuthError::Unauthorized(detail.to_string())),
                // Throttling and similar: not the credential's fault.
                _ if status == 429 => Err(AuthError::Transient("the server is busy".into())),
                _ => Err(AuthError::Unauthorized(detail.to_string())),
            }
        }
        _ => Err(AuthError::Transient(format!("the server answered {status}"))),
    }
}

pub fn exchange_code(http: &dyn Http, base: &str, port: u16, code: &str, verifier: &str) -> Result<Tokens, AuthError> {
    let redirect = redirect_uri(port);
    let r = http
        .post_form(
            &endpoint(base, "/oauth/token")?,
            &[("grant_type", "authorization_code"), ("code", code), ("redirect_uri", &redirect), ("client_id", CLIENT_ID), ("code_verifier", verifier)],
        )
        .map_err(AuthError::Transient)?;
    parse_token_response(r.status, &r.body)
}

pub fn refresh(http: &dyn Http, base: &str, refresh_token: &str) -> Result<Tokens, AuthError> {
    let r = http
        .post_form(&endpoint(base, "/oauth/token")?, &[("grant_type", "refresh_token"), ("refresh_token", refresh_token), ("client_id", CLIENT_ID)])
        .map_err(AuthError::Transient)?;
    parse_token_response(r.status, &r.body)
}

/// Best effort: the credential is deleted locally either way.
pub fn revoke(http: &dyn Http, base: &str, refresh_token: &str) {
    if let Ok(url) = endpoint(base, "/oauth/revoke") {
        let _ = http.post_form(&url, &[("client_id", CLIENT_ID), ("token", refresh_token), ("token_type_hint", "refresh_token")]);
    }
}

#[cfg(test)]
mod tests;
