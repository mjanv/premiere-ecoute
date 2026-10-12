//! The server address the user chose, kept between runs: `%APPDATA%\premiere-ecoute-player\server.txt`.
//! `PLAYER_HUB_URL` still wins when it is set (development, scripts).

use std::path::{Path, PathBuf};

const FILE: &str = "server.txt";

pub fn dir() -> Option<PathBuf> {
    std::env::var_os("APPDATA").map(|appdata| PathBuf::from(appdata).join("premiere-ecoute-player"))
}

pub fn load_from(dir: &Path) -> Option<String> {
    let text = std::fs::read_to_string(dir.join(FILE)).ok()?;
    let text = text.trim();
    (!text.is_empty()).then(|| text.to_string())
}

/// Written to a temporary file first, so a crash cannot leave a half-written address.
pub fn save_to(dir: &Path, address: &str) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)?;
    let tmp = dir.join(format!("{FILE}.tmp"));
    std::fs::write(&tmp, address.trim())?;
    std::fs::rename(tmp, dir.join(FILE))
}

pub fn load() -> Option<String> {
    load_from(&dir()?)
}

pub fn save(address: &str) -> Result<(), String> {
    let dir = dir().ok_or("cannot find a place to save the server address")?;
    save_to(&dir, address).map_err(|e| format!("cannot save the server address: {e}"))
}

/// The address to use: the environment variable first, then the saved one.
pub fn resolve(env: Option<&str>, saved: Option<&str>) -> Option<String> {
    [env, saved].into_iter().flatten().map(str::trim).find(|s| !s.is_empty()).map(str::to_string)
}

#[cfg(test)]
mod tests;
