use super::*;
use crate::remote::credentials::MemoryStore;
use crate::remote::oauth::HttpResponse;
use std::cell::RefCell;
use std::collections::VecDeque;
use std::rc::Rc;
use std::sync::Arc;

type Posted = Rc<RefCell<Vec<(String, Vec<(String, String)>)>>>;

#[derive(Clone)]
struct FakeHttp {
    replies: Rc<RefCell<VecDeque<Result<HttpResponse, String>>>>,
    posted: Posted,
}

impl FakeHttp {
    fn new(replies: Vec<Result<HttpResponse, String>>) -> Self {
        Self {
            replies: Rc::new(RefCell::new(replies.into())),
            posted: Rc::default(),
        }
    }

    fn form(&self, i: usize) -> std::collections::BTreeMap<String, String> {
        self.posted.borrow()[i].1.iter().cloned().collect()
    }
}

impl Http for FakeHttp {
    fn post_form(&self, url: &str, form: &[(&str, &str)]) -> Result<HttpResponse, String> {
        self.posted.borrow_mut().push((
            url.to_string(),
            form.iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
        ));
        self.replies
            .borrow_mut()
            .pop_front()
            .unwrap_or(Err("no reply scripted".into()))
    }
}

fn tokens(access: &str, refresh: &str, secs: u64) -> Result<HttpResponse, String> {
    Ok(HttpResponse {
        status: 200,
        body: format!(
            r#"{{"token_type":"Bearer","access_token":"{access}","expires_in":{secs},"refresh_token":"{refresh}"}}"#
        ),
    })
}

fn status(code: u16, body: &str) -> Result<HttpResponse, String> {
    Ok(HttpResponse {
        status: code,
        body: body.into(),
    })
}

/// A store that several `Auth` pieces can look at.
#[derive(Clone, Default)]
struct SharedStore(Arc<MemoryStore>);

impl CredentialStore for SharedStore {
    fn load(&self) -> Result<Option<String>, String> {
        self.0.load()
    }
    fn save(&self, t: &str) -> Result<(), String> {
        self.0.save(t)
    }
    fn delete(&self) -> Result<(), String> {
        self.0.delete()
    }
}

fn auth(
    replies: Vec<Result<HttpResponse, String>>,
    stored: Option<&str>,
) -> (Auth, FakeHttp, SharedStore) {
    let http = FakeHttp::new(replies);
    let store = SharedStore::default();
    *store.0.value.lock().unwrap() = stored.map(str::to_string);
    (
        Auth::new(
            Box::new(http.clone()),
            Box::new(store.clone()),
            "http://localhost:4000".into(),
        ),
        http,
        store,
    )
}

fn stored(store: &SharedStore) -> Option<String> {
    store.0.value.lock().unwrap().clone()
}

#[test]
fn without_a_saved_sign_in_there_is_nothing_to_do() {
    let (mut a, http, _) = auth(vec![], None);
    assert_eq!(a.access_token(Instant::now()), Err(AuthError::NotEnrolled));
    assert!(http.posted.borrow().is_empty());
}

#[test]
fn a_refresh_returns_the_access_token_and_saves_the_rotated_refresh_token() {
    let (mut a, http, store) = auth(vec![tokens("A1", "R2", 3600)], Some("R1"));
    assert_eq!(a.access_token(Instant::now()), Ok("A1".into()));
    assert_eq!(stored(&store).as_deref(), Some("R2"));
    let form = http.form(0);
    assert_eq!(
        (form["grant_type"].as_str(), form["refresh_token"].as_str()),
        ("refresh_token", "R1")
    );
    assert_eq!(form["client_id"], oauth::CLIENT_ID);
    assert!(http.posted.borrow()[0].0.ends_with("/oauth/token"));
}

#[test]
fn the_access_token_is_reused_until_a_minute_before_it_expires() {
    let (mut a, http, _) = auth(
        vec![tokens("A1", "R2", 3600), tokens("A2", "R3", 3600)],
        Some("R1"),
    );
    let t0 = Instant::now();
    assert_eq!(a.access_token(t0), Ok("A1".into()));
    assert_eq!(
        a.access_token(t0 + Duration::from_secs(3000)),
        Ok("A1".into())
    );
    assert_eq!(http.posted.borrow().len(), 1);
    assert_eq!(
        a.access_token(t0 + Duration::from_secs(3541)),
        Ok("A2".into())
    );
    assert_eq!(http.form(1)["refresh_token"], "R2"); // always the newest refresh token
}

#[test]
fn a_dead_credential_is_forgotten_and_reported() {
    let (mut a, _, store) = auth(
        vec![status(
            400,
            r#"{"error":"invalid_grant","error_description":"Token revoked"}"#,
        )],
        Some("R1"),
    );
    assert_eq!(
        a.access_token(Instant::now()),
        Err(AuthError::Unauthorized("Token revoked".into()))
    );
    assert_eq!(stored(&store), None);
    assert_eq!(a.access_token(Instant::now()), Err(AuthError::NotEnrolled));
}

#[test]
fn a_server_error_keeps_the_credential_for_later() {
    let (mut a, _, store) = auth(
        vec![
            status(503, ""),
            Err("connection refused".into()),
            tokens("A1", "R2", 3600),
        ],
        Some("R1"),
    );
    let now = Instant::now();
    assert!(matches!(a.access_token(now), Err(AuthError::Transient(_))));
    assert!(matches!(a.access_token(now), Err(AuthError::Transient(_))));
    assert_eq!(stored(&store).as_deref(), Some("R1"));
    assert_eq!(a.access_token(now), Ok("A1".into()));
}

#[test]
fn a_failing_store_cannot_lose_the_rotated_token_and_the_save_is_retried() {
    let (mut a, http, store) = auth(
        vec![tokens("A1", "R2", 100), tokens("A2", "R3", 3600)],
        Some("R1"),
    );
    *store.0.fail_saves.lock().unwrap() = true;
    let t0 = Instant::now();
    assert_eq!(a.access_token(t0), Ok("A1".into()));
    assert_eq!(stored(&store).as_deref(), Some("R1")); // stale on disk, newest in memory

    // The next refresh must use the in-memory token: the stored one was revoked by the server.
    assert_eq!(
        a.access_token(t0 + Duration::from_secs(200)),
        Ok("A2".into())
    );
    assert_eq!(http.form(1)["refresh_token"], "R2");

    *store.0.fail_saves.lock().unwrap() = false;
    assert_eq!(
        a.access_token(t0 + Duration::from_secs(201)),
        Ok("A2".into())
    );
    assert_eq!(stored(&store).as_deref(), Some("R3"));
}

#[test]
fn invalidating_forces_a_refresh_even_when_the_token_looks_valid() {
    let (mut a, http, _) = auth(
        vec![tokens("A1", "R2", 3600), tokens("A2", "R3", 3600)],
        Some("R1"),
    );
    let now = Instant::now();
    a.access_token(now).unwrap();
    a.invalidate_access();
    assert_eq!(a.access_token(now), Ok("A2".into()));
    assert_eq!(http.posted.borrow().len(), 2);
}

#[test]
fn forgetting_revokes_on_the_server_and_deletes_locally() {
    let (mut a, http, store) = auth(vec![status(200, "")], Some("R1"));
    a.forget();
    assert_eq!(stored(&store), None);
    assert!(http.posted.borrow()[0].0.ends_with("/oauth/revoke"));
    assert_eq!(http.form(0)["token"], "R1");
    assert_eq!(http.form(0)["token_type_hint"], "refresh_token");
    assert_eq!(a.access_token(Instant::now()), Err(AuthError::NotEnrolled));
}

/// Plays the browser: reads the authorize URL and comes back to the loopback redirect.
struct FakeBrowser {
    outcome: &'static str,
    seen: Rc<RefCell<Option<String>>>,
}

impl Browser for FakeBrowser {
    fn open(&self, url: &str) -> Result<(), String> {
        *self.seen.borrow_mut() = Some(url.to_string());
        let parsed = url::Url::parse(url).unwrap();
        let q: std::collections::BTreeMap<_, _> = parsed.query_pairs().into_owned().collect();
        let redirect = url::Url::parse(&q["redirect_uri"]).unwrap();
        let port = redirect.port().unwrap();
        let target = match self.outcome {
            "approve" => format!("/cb?code=CODE1&state={}", q["state"]),
            _ => format!("/cb?error=access_denied&state={}", q["state"]),
        };
        std::thread::spawn(move || {
            use std::io::{Read, Write};
            let mut s = std::net::TcpStream::connect(("127.0.0.1", port)).unwrap();
            write!(s, "GET {target} HTTP/1.1\r\nHost: x\r\n\r\n").unwrap();
            let mut sink = String::new();
            let _ = s.read_to_string(&mut sink);
        });
        Ok(())
    }
}

#[test]
fn signing_in_exchanges_the_code_with_the_matching_pkce_verifier_and_saves_the_credential() {
    let (mut a, http, store) = auth(vec![tokens("A1", "R1", 3600)], None);
    let seen = Rc::new(RefCell::new(None));
    let browser = FakeBrowser {
        outcome: "approve",
        seen: seen.clone(),
    };
    assert_eq!(
        a.sign_in(&browser, Duration::from_secs(5), Instant::now()),
        Ok(())
    );

    let form = http.form(0);
    assert_eq!(
        (form["grant_type"].as_str(), form["code"].as_str()),
        ("authorization_code", "CODE1")
    );
    assert_eq!(form["client_id"], oauth::CLIENT_ID);
    let url = url::Url::parse(seen.borrow().as_ref().unwrap()).unwrap();
    let challenge = url
        .query_pairs()
        .find(|(k, _)| k == "code_challenge")
        .unwrap()
        .1
        .into_owned();
    assert_eq!(oauth::code_challenge(&form["code_verifier"]), challenge);
    assert_eq!(
        form["redirect_uri"],
        url.query_pairs()
            .find(|(k, _)| k == "redirect_uri")
            .unwrap()
            .1
    );

    assert_eq!(stored(&store).as_deref(), Some("R1"));
    assert_eq!(a.access_token(Instant::now()), Ok("A1".into()));
}

#[test]
fn declining_in_the_browser_signs_nobody_in() {
    let (mut a, http, store) = auth(vec![], None);
    let browser = FakeBrowser {
        outcome: "deny",
        seen: Rc::default(),
    };
    assert_eq!(
        a.sign_in(&browser, Duration::from_secs(5), Instant::now()),
        Err(AuthError::Denied)
    );
    assert!(http.posted.borrow().is_empty());
    assert_eq!(stored(&store), None);
}

#[test]
fn a_browser_that_cannot_open_is_a_transient_error() {
    struct Broken;
    impl Browser for Broken {
        fn open(&self, _: &str) -> Result<(), String> {
            Err("no default browser".into())
        }
    }
    let (mut a, _, _) = auth(vec![], None);
    assert!(matches!(
        a.sign_in(&Broken, Duration::from_millis(100), Instant::now()),
        Err(AuthError::Transient(_))
    ));
}
