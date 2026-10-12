use super::*;
use std::net::TcpStream;

#[test]
fn the_challenge_matches_the_rfc_7636_vector() {
    assert_eq!(code_challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
}

#[test]
fn verifiers_are_64_unreserved_characters_and_differ() {
    let (a, b) = (code_verifier(), code_verifier());
    assert_eq!(a.len(), 64);
    assert!(a.bytes().all(|c| UNRESERVED.contains(&c)));
    assert_ne!(a, b);
    assert_ne!(random_state(), random_state());
}

#[test]
fn the_authorize_url_has_exactly_the_parameters_of_the_guide() {
    let url = Url::parse(&authorize_url("http://localhost:4000", 51234, "st", "ch").unwrap()).unwrap();
    assert_eq!((url.host_str(), url.port(), url.path()), (Some("localhost"), Some(4000), "/oauth/authorize"));
    let q: std::collections::BTreeMap<_, _> = url.query_pairs().into_owned().collect();
    assert_eq!(q["response_type"], "code");
    assert_eq!(q["client_id"], CLIENT_ID);
    assert_eq!(q["redirect_uri"], "http://127.0.0.1:51234/cb");
    assert_eq!(q["scope"], "player");
    assert_eq!((q["state"].as_str(), q["code_challenge"].as_str(), q["code_challenge_method"].as_str()), ("st", "ch", "S256"));
    assert_eq!(q.len(), 7);
}

#[test]
fn callbacks_are_checked_by_state_first() {
    let code = |l: &str| parse_callback(l, "good");
    assert_eq!(code("GET /cb?code=abc&state=good HTTP/1.1"), Callback::Code("abc".into()));
    assert_eq!(code("GET /cb?state=good&code=a%20b HTTP/1.1"), Callback::Code("a b".into()));
    assert_eq!(code("GET /cb?error=access_denied&state=good HTTP/1.1"), Callback::Denied);
    // Wrong or missing state never yields a code, even for a denial.
    assert_eq!(code("GET /cb?code=abc&state=evil HTTP/1.1"), Callback::Ignore);
    assert_eq!(code("GET /cb?code=abc HTTP/1.1"), Callback::Ignore);
    assert_eq!(code("GET /cb?error=access_denied&state=evil HTTP/1.1"), Callback::Ignore);
    assert_eq!(code("GET /favicon.ico HTTP/1.1"), Callback::Ignore);
    assert_eq!(code("POST /cb?code=abc&state=good HTTP/1.1"), Callback::Ignore);
    assert_eq!(code("GET /cb?code=&state=good HTTP/1.1"), Callback::Ignore);
    assert_eq!(code(""), Callback::Ignore);
}

fn browser_hits(port: u16, requests: Vec<String>) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        for target in requests {
            let mut s = TcpStream::connect((Ipv4Addr::LOCALHOST, port)).unwrap();
            write!(s, "GET {target} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n").unwrap();
            let mut sink = String::new();
            let _ = s.read_to_string(&mut sink);
            std::thread::sleep(Duration::from_millis(20));
        }
    })
}

#[test]
fn the_listener_ignores_strangers_and_returns_the_first_valid_code() {
    let (listener, port) = bind_loopback().unwrap();
    let browser = browser_hits(port, vec!["/favicon.ico".into(), "/cb?code=x&state=wrong".into(), "/cb?code=the-code&state=s1".into()]);
    assert_eq!(wait_for_callback(&listener, "s1", Duration::from_secs(5)), Ok("the-code".into()));
    browser.join().unwrap();
}

#[test]
fn a_denial_and_a_silence_are_distinguished() {
    let (listener, port) = bind_loopback().unwrap();
    let browser = browser_hits(port, vec!["/cb?error=access_denied&state=s1".into()]);
    assert_eq!(wait_for_callback(&listener, "s1", Duration::from_secs(5)), Err(AuthError::Denied));
    browser.join().unwrap();

    let (quiet, _) = bind_loopback().unwrap();
    assert_eq!(wait_for_callback(&quiet, "s1", Duration::from_millis(200)), Err(AuthError::TimedOut));
}

#[test]
fn the_listener_only_binds_the_loopback_interface() {
    let (listener, port) = bind_loopback().unwrap();
    assert!(listener.local_addr().unwrap().ip().is_loopback());
    assert!(port >= 1024);
}

#[test]
fn token_responses_map_to_tokens_or_precise_errors() {
    let ok = r#"{"token_type":"Bearer","access_token":"A","expires_in":3600,"refresh_token":"R"}"#;
    assert_eq!(parse_token_response(200, ok), Ok(Tokens { access: "A".into(), refresh: "R".into(), expires_in: Duration::from_secs(3600) }));
    assert!(matches!(parse_token_response(200, "{}"), Err(AuthError::Transient(_))));
    assert!(matches!(parse_token_response(200, "not json"), Err(AuthError::Transient(_))));
    let grant = r#"{"error":"invalid_grant","error_description":"Code reused"}"#;
    assert_eq!(parse_token_response(400, grant), Err(AuthError::Unauthorized("Code reused".into())));
    assert!(matches!(parse_token_response(429, "{}"), Err(AuthError::Transient(_))));
    assert!(matches!(parse_token_response(500, ""), Err(AuthError::Transient(_))));
    assert!(matches!(parse_token_response(503, "<html>"), Err(AuthError::Transient(_))));
}
