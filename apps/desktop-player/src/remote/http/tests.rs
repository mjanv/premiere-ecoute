use super::*;
use std::io::{Read, Write};
use std::net::TcpListener;

/// Serves one request with `reply` and returns what the client sent.
fn serve_once(reply: &'static str) -> (u16, std::thread::JoinHandle<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let handle = std::thread::spawn(move || {
        let (mut s, _) = listener.accept().unwrap();
        s.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        let mut request = Vec::new();
        let mut chunk = [0u8; 1024];
        loop {
            let n = s.read(&mut chunk).unwrap();
            request.extend_from_slice(&chunk[..n]);
            let text = String::from_utf8_lossy(&request).to_string();
            if let Some((head, body)) = text.split_once("\r\n\r\n") {
                let len = head
                    .lines()
                    .find_map(|l| {
                        l.to_lowercase()
                            .strip_prefix("content-length:")
                            .map(|v| v.trim().parse::<usize>().unwrap())
                    })
                    .unwrap_or(0);
                if body.len() >= len {
                    break;
                }
            }
            if n == 0 {
                break;
            }
        }
        s.write_all(reply.as_bytes()).unwrap();
        String::from_utf8_lossy(&request).to_string()
    });
    (port, handle)
}

#[test]
fn a_form_is_posted_urlencoded_and_a_4xx_body_is_returned_not_raised() {
    let (port, server) = serve_once(
        "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nContent-Length: 34\r\nConnection: close\r\n\r\n{\"error\":\"invalid_grant\",\"x\":\"yy\"}",
    );
    let r = UreqHttp::new()
        .post_form(
            &format!("http://127.0.0.1:{port}/oauth/token"),
            &[("grant_type", "refresh_token"), ("refresh_token", "a b&c")],
        )
        .unwrap();
    assert_eq!(r.status, 400);
    assert!(r.body.contains("invalid_grant"));
    let request = server.join().unwrap();
    assert!(
        request.starts_with("POST /oauth/token HTTP/1.1"),
        "{request}"
    );
    assert!(
        request
            .to_lowercase()
            .contains("content-type: application/x-www-form-urlencoded")
    );
    assert!(
        request.ends_with("grant_type=refresh_token&refresh_token=a+b%26c")
            || request.ends_with("grant_type=refresh_token&refresh_token=a%20b%26c"),
        "{request}"
    );
}

#[test]
fn redirects_are_not_followed() {
    let (port, server) = serve_once(
        "HTTP/1.1 302 Found\r\nLocation: http://evil.invalid/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
    );
    let r = UreqHttp::new()
        .post_form(
            &format!("http://127.0.0.1:{port}/oauth/token"),
            &[("a", "b")],
        )
        .unwrap();
    assert_eq!(r.status, 302);
    server.join().unwrap();
}

#[test]
fn an_unreachable_server_is_an_error_not_a_panic() {
    let port = {
        let l = TcpListener::bind("127.0.0.1:0").unwrap();
        l.local_addr().unwrap().port()
    };
    assert!(
        UreqHttp::new()
            .post_form(&format!("http://127.0.0.1:{port}/x"), &[("a", "b")])
            .is_err()
    );
}
