//! The WebSocket to the backend. Timeouts on every step, a 64 KiB frame limit, and the access
//! token in the `X-Access-Token` header (never in the URL).

use super::session::{Transport, TransportError};
use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;
use tungstenite::client::IntoClientRequest;
use tungstenite::http::HeaderValue;
use tungstenite::protocol::WebSocketConfig;
use tungstenite::stream::MaybeTlsStream;
use tungstenite::{Error as WsError, HandshakeError, Message, WebSocket, client_tls_with_config};
use url::Url;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
const WRITE_TIMEOUT: Duration = Duration::from_secs(5);
const MAX_FRAME: usize = 64 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ConnectError {
    /// The upgrade was refused with 401 or 403: the access token is not accepted.
    Unauthorized,
    Failed(String),
}

pub struct WsTransport {
    socket: WebSocket<MaybeTlsStream<TcpStream>>,
}

fn connect_tcp(url: &Url) -> Result<TcpStream, ConnectError> {
    let host = url.host_str().ok_or_else(|| ConnectError::Failed("the server address has no host".into()))?;
    let port = url.port_or_known_default().ok_or_else(|| ConnectError::Failed("the server address has no port".into()))?;
    let addrs = (host, port).to_socket_addrs().map_err(|e| ConnectError::Failed(format!("cannot resolve {host}: {e}")))?;
    let mut last = format!("no address for {host}");
    for addr in addrs {
        match TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT) {
            Ok(stream) => return Ok(stream),
            Err(e) => last = e.to_string(),
        }
    }
    Err(ConnectError::Failed(last))
}

impl WsTransport {
    pub fn connect(ws_url: &str, access_token: &str) -> Result<Self, ConnectError> {
        let url = Url::parse(ws_url).map_err(|e| ConnectError::Failed(format!("bad server address: {e}")))?;
        if !matches!(url.scheme(), "ws" | "wss") {
            return Err(ConnectError::Failed("the server address must start with ws:// or wss://".into()));
        }
        let stream = connect_tcp(&url)?;
        let _ = stream.set_nodelay(true);
        let _ = stream.set_write_timeout(Some(WRITE_TIMEOUT));
        let _ = stream.set_read_timeout(Some(HANDSHAKE_TIMEOUT));

        let mut request = ws_url.into_client_request().map_err(|e| ConnectError::Failed(e.to_string()))?;
        let token = HeaderValue::from_str(access_token).map_err(|_| ConnectError::Failed("the access token is not a valid header".into()))?;
        request.headers_mut().insert("X-Access-Token", token);

        let config = WebSocketConfig::default().max_message_size(Some(MAX_FRAME)).max_frame_size(Some(MAX_FRAME));
        match client_tls_with_config(request, stream, Some(config), None) {
            Ok((socket, _)) => Ok(Self { socket }),
            Err(HandshakeError::Failure(WsError::Http(response))) => match response.status().as_u16() {
                401 | 403 => Err(ConnectError::Unauthorized),
                status => Err(ConnectError::Failed(format!("the server answered {status}"))),
            },
            Err(e) => Err(ConnectError::Failed(e.to_string())),
        }
    }

    fn tcp(&self) -> Option<&TcpStream> {
        match self.socket.get_ref() {
            MaybeTlsStream::Plain(s) => Some(s),
            MaybeTlsStream::Rustls(s) => Some(s.get_ref()),
            _ => None,
        }
    }
}

fn closed() -> TransportError {
    TransportError("the connection was closed".into())
}

impl Transport for WsTransport {
    fn send(&mut self, frame: &str) -> Result<(), TransportError> {
        self.socket.send(Message::text(frame)).map_err(|e| TransportError(e.to_string()))
    }

    fn recv(&mut self, timeout: Duration) -> Result<Option<String>, TransportError> {
        if let Some(tcp) = self.tcp() {
            let _ = tcp.set_read_timeout(Some(timeout.max(Duration::from_millis(1))));
        }
        match self.socket.read() {
            Ok(Message::Text(text)) => Ok(Some(text.as_str().to_string())),
            Ok(Message::Close(_)) => Err(closed()),
            Ok(Message::Ping(_)) => {
                // tungstenite queued the pong; push it out.
                let _ = self.socket.flush();
                Ok(None)
            }
            Ok(_) => Ok(None),
            Err(WsError::Io(e)) if matches!(e.kind(), std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut) => Ok(None),
            Err(WsError::ConnectionClosed | WsError::AlreadyClosed) => Err(closed()),
            Err(e) => Err(TransportError(e.to_string())),
        }
    }

    fn close(&mut self) {
        if let Some(tcp) = self.tcp() {
            let _ = tcp.set_write_timeout(Some(Duration::from_secs(1)));
        }
        let _ = self.socket.close(None);
        let _ = self.socket.flush();
    }
}

#[cfg(test)]
mod tests;
