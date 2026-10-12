use super::*;
use crate::player::{Command, Reply, Request, Snapshot};
use crate::remote::session::{Config, End, Session, SystemClock};
use crate::remote_status::RemoteStatus;
use std::net::TcpListener;
use std::sync::{Arc, Mutex};
use std::time::Instant;
use tungstenite::handshake::server::{ErrorResponse, Request as HsRequest, Response as HsResponse};

/// A one-connection WebSocket server. `check` sees the upgrade request (path and token) and may refuse it.
fn server<F>(check: F, serve: impl FnOnce(WebSocket<TcpStream>) + Send + 'static) -> (u16, std::thread::JoinHandle<()>)
where
    F: FnOnce(&HsRequest) -> Result<(), u16> + Send + 'static,
{
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let handle = std::thread::spawn(move || {
        let (stream, _) = listener.accept().unwrap();
        let callback = move |req: &HsRequest, resp: HsResponse| -> Result<HsResponse, ErrorResponse> {
            match check(req) {
                Ok(()) => Ok(resp),
                Err(status) => Err(tungstenite::http::Response::builder().status(status).body(None).unwrap()),
            }
        };
        if let Ok(ws) = tungstenite::accept_hdr(stream, callback) {
            serve(ws);
        }
    });
    (port, handle)
}

fn url(port: u16) -> String {
    format!("ws://127.0.0.1:{port}/player/websocket?vsn=2.0.0")
}

#[test]
fn the_token_travels_in_a_header_and_frames_flow_both_ways() {
    let (port, srv) = server(
        |req| {
            assert_eq!(req.headers().get("X-Access-Token").unwrap(), "tok-123");
            assert_eq!(req.uri().path(), "/player/websocket");
            assert_eq!(req.uri().query(), Some("vsn=2.0.0"));
            assert!(!req.uri().to_string().contains("tok-123"));
            Ok(())
        },
        |mut ws| {
            ws.send(Message::text("hello from the server")).unwrap();
            let got = ws.read().unwrap();
            assert_eq!(got.into_text().unwrap().as_str(), "hello from the client");
        },
    );
    let mut t = WsTransport::connect(&url(port), "tok-123").unwrap();
    assert_eq!(t.recv(Duration::from_secs(5)).unwrap().as_deref(), Some("hello from the server"));
    t.send("hello from the client").unwrap();
    srv.join().unwrap();
}

#[test]
fn a_refused_token_is_reported_as_unauthorized() {
    for status in [401, 403] {
        let (port, srv) = server(move |_| Err(status), |_| {});
        assert_eq!(WsTransport::connect(&url(port), "bad").err(), Some(ConnectError::Unauthorized), "{status}");
        srv.join().unwrap();
    }
    let (port, srv) = server(|_| Err(503), |_| {});
    assert!(matches!(WsTransport::connect(&url(port), "x").err(), Some(ConnectError::Failed(_))));
    srv.join().unwrap();
}

#[test]
fn reading_with_nothing_to_read_times_out_cleanly_and_a_server_close_is_an_error() {
    let (port, srv) = server(|_| Ok(()), |mut ws| {
        std::thread::sleep(Duration::from_millis(400));
        let _ = ws.close(None);
        let _ = ws.flush();
        std::thread::sleep(Duration::from_millis(200));
    });
    let mut t = WsTransport::connect(&url(port), "t").unwrap();
    let started = Instant::now();
    assert_eq!(t.recv(Duration::from_millis(100)), Ok(None));
    assert!(started.elapsed() >= Duration::from_millis(90));
    let mut result = Ok(None);
    for _ in 0..40 {
        result = t.recv(Duration::from_millis(100));
        if result != Ok(None) {
            break;
        }
    }
    assert!(result.is_err(), "{result:?}");
    srv.join().unwrap();
}

#[test]
fn connecting_to_nothing_or_with_a_bad_scheme_fails_without_panicking() {
    let port = {
        let l = TcpListener::bind("127.0.0.1:0").unwrap();
        l.local_addr().unwrap().port()
    };
    assert!(matches!(WsTransport::connect(&url(port), "t").err(), Some(ConnectError::Failed(_))));
    assert!(matches!(WsTransport::connect("http://127.0.0.1:1/x", "t").err(), Some(ConnectError::Failed(_))));
    assert!(matches!(WsTransport::connect("not a url", "t").err(), Some(ConnectError::Failed(_))));
    assert!(matches!(WsTransport::connect(&url(port), "bad\ntoken").err(), Some(ConnectError::Failed(_))));
}

#[test]
fn a_whole_session_runs_over_a_real_socket() {
    let (port, srv) = server(|_| Ok(()), |mut ws| {
        // join, then the first snapshot immediately
        let join: serde_json::Value = serde_json::from_str(ws.read().unwrap().into_text().unwrap().as_str()).unwrap();
        assert_eq!((join[2].as_str(), join[3].as_str()), (Some("desktop:me"), Some("phx_join")));
        ws.send(Message::text(r#"["1","1","desktop:me","phx_reply",{"status":"ok","response":{"snapshot_interval_ms":1000}}]"#)).unwrap();
        let snap: serde_json::Value = serde_json::from_str(ws.read().unwrap().into_text().unwrap().as_str()).unwrap();
        assert_eq!((snap[3].as_str(), snap[4]["seq"].as_u64()), (Some("snapshot"), Some(1)));
        // a command, then its ack
        ws.send(Message::text(r#"["1",null,"desktop:me","command",{"id":"c1","type":"next","args":{},"ttl_ms":10000}]"#)).unwrap();
        loop {
            let m: serde_json::Value = serde_json::from_str(ws.read().unwrap().into_text().unwrap().as_str()).unwrap();
            if m[3] == "ack" {
                assert_eq!((m[4]["command_id"].as_str(), m[4]["status"].as_str()), (Some("c1"), Some("ok")));
                break;
            }
        }
        ws.send(Message::text(r#"["1",null,"desktop:me","disconnect",{"reason":"revoked"}]"#)).unwrap();
        let _ = ws.flush();
    });

    // The player worker, as a thread that does what `player::run` does with a request.
    let (commands, rx) = std::sync::mpsc::channel::<Request>();
    let ran = Arc::new(Mutex::new(Vec::new()));
    let worker = {
        let ran = ran.clone();
        std::thread::spawn(move || {
            while let Ok(request) = rx.recv() {
                ran.lock().unwrap().push(request.command.clone());
                if let Some(reply) = request.reply {
                    let _ = reply.send(Reply::Done);
                }
            }
        })
    };

    let mut transport = WsTransport::connect(&url(port), "tok").unwrap();
    let status = Mutex::new(RemoteStatus::default());
    let snapshot = Snapshot::default;
    let config = Config::new("sess".into(), "0.1.0".into());
    let ended = Session { transport: &mut transport, clock: &SystemClock, executor: &commands, snapshot: &snapshot, status: &status, config: &config, cancelled: &|| false }.run();

    assert_eq!(ended.reason, End::Revoked);
    drop(commands);
    worker.join().unwrap();
    assert_eq!(*ran.lock().unwrap(), [Command::Next]);
    srv.join().unwrap();
}
