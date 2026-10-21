//! A log file next to the app: `%LOCALAPPDATA%\premiere-ecoute-player\player.log`. The release exe
//! has no console, so without it a failed token refresh or a crashed worker leaves no trace.
//!
//! Plain lines (`2026-10-21T20:30:05Z INFO linked`), one file, rotated to `player.log.old` at 1 MB.
//! Never log tokens, credentials or what the user typed. Before `init` every call does nothing, so
//! tests and previews stay quiet.

use std::ffi::OsString;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

const FOLDER: &str = "premiere-ecoute-player";
const FILE: &str = "player.log";
const OLD: &str = "player.log.old";
const MAX_BYTES: u64 = 1024 * 1024;

static SINK: OnceLock<Mutex<File>> = OnceLock::new();

fn needs_rotation(len: u64) -> bool {
    len > MAX_BYTES
}

fn dir_in(local_app_data: Option<OsString>) -> Option<PathBuf> {
    local_app_data.map(|d| PathBuf::from(d).join(FOLDER))
}

/// `1970-01-01T00:00:00Z` from seconds since the Unix epoch (days to a civil date, after Howard
/// Hinnant's algorithm).
fn timestamp(epoch_secs: u64) -> String {
    let days = (epoch_secs / 86_400) as i64;
    let secs = epoch_secs % 86_400;
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}Z",
        secs / 3600,
        secs % 3600 / 60,
        secs % 60
    )
}

fn line(epoch_secs: u64, level: &str, message: &str) -> String {
    let message = message.replace("\r\n", " | ").replace(['\n', '\r'], " | ");
    format!("{} {level} {message}", timestamp(epoch_secs))
}

fn panic_line(message: &str, location: Option<(&str, u32)>) -> String {
    match location {
        Some((file, line)) => format!("panic: {message} at {file}:{line}"),
        None => format!("panic: {message}"),
    }
}

fn write(level: &str, message: &str) {
    let Some(sink) = SINK.get() else {
        return;
    };
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let mut file = sink.lock().unwrap_or_else(|e| e.into_inner());
    // A log that cannot be written must never take the app down.
    let _ = writeln!(file, "{}", line(now, level, message));
}

pub fn info(message: impl AsRef<str>) {
    write("INFO", message.as_ref());
}

pub fn warn(message: impl AsRef<str>) {
    write("WARN", message.as_ref());
}

/// Opens the log (rotating it when it is large) and records panics. Call once at startup.
pub fn init() {
    let Some(dir) = dir_in(std::env::var_os("LOCALAPPDATA")) else {
        return;
    };
    if std::fs::create_dir_all(&dir).is_err() {
        return;
    }
    let path = dir.join(FILE);
    if std::fs::metadata(&path).is_ok_and(|m| needs_rotation(m.len())) {
        let _ = std::fs::rename(&path, dir.join(OLD));
    }
    let Ok(file) = OpenOptions::new().create(true).append(true).open(&path) else {
        return;
    };
    if SINK.set(Mutex::new(file)).is_err() {
        return;
    }
    let previous = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let message = info
            .payload()
            .downcast_ref::<&str>()
            .map(|s| s.to_string())
            .or_else(|| info.payload().downcast_ref::<String>().cloned())
            .unwrap_or_else(|| "unknown".into());
        let thread = std::thread::current();
        let location = info.location().map(|l| (l.file(), l.line()));
        warn(format!(
            "[{}] {}",
            thread.name().unwrap_or("?"),
            panic_line(&message, location)
        ));
        previous(info);
    }));
    info(format!("started, version {}", env!("CARGO_PKG_VERSION")));
}

#[cfg(test)]
mod tests;
