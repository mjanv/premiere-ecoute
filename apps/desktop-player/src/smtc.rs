//! Reads and controls the local Spotify app through the Windows System Media
//! Transport Controls (the API behind the volume/media flyout).

use crate::artwork::Artwork;
use crate::identity::{Identity, UriTracker};
use crate::player::{Backend, Playback, Repeat, Snapshot, autoplay_uri, current_position};
use crate::volume;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use windows::Foundation::{DateTime, TimeSpan};
use windows::Media::Control::{
    GlobalSystemMediaTransportControlsSession as Session,
    GlobalSystemMediaTransportControlsSessionManager as Manager,
    GlobalSystemMediaTransportControlsSessionMediaProperties,
    GlobalSystemMediaTransportControlsSessionPlaybackStatus as Status,
};
use windows::Media::MediaPlaybackAutoRepeatMode;
use windows::Storage::Streams::DataReader;

/// Cover of the current track. SMTC hands out the thumbnail slightly after a track change, so a
/// miss is retried a few polls before giving up until the track changes.
#[derive(Default)]
struct Cover {
    track: (String, String, String),
    artwork: Option<Artwork>,
    tries: u8,
}

const COVER_TRIES: u8 = 4;
const COVER_MAX_BYTES: u32 = 8 * 1024 * 1024;

#[derive(Default)]
pub struct Smtc {
    /// The last track written to the log, so each track is logged once.
    logged: (String, String, String),
    cover: Cover,
    uris: UriTracker,
}

fn read_thumbnail(
    props: &GlobalSystemMediaTransportControlsSessionMediaProperties,
) -> Option<Vec<u8>> {
    let stream = props.Thumbnail().ok()?.OpenReadAsync().ok()?.join().ok()?;
    let size = u32::try_from(stream.Size().ok()?).ok()?;
    if size == 0 || size > COVER_MAX_BYTES {
        return None;
    }
    let reader = DataReader::CreateDataReader(&stream).ok()?;
    reader.LoadAsync(size).ok()?.join().ok()?;
    let mut buf = vec![0u8; size as usize];
    reader.ReadBytes(&mut buf).ok()?;
    Some(buf)
}

impl Smtc {
    fn cover_for(
        &mut self,
        props: &GlobalSystemMediaTransportControlsSessionMediaProperties,
        track: (String, String, String),
    ) -> Option<Artwork> {
        if self.cover.track != track {
            self.cover = Cover {
                track,
                ..Cover::default()
            };
        }
        if self.cover.artwork.is_none()
            && self.cover.tries < COVER_TRIES
            && !self.cover.track.0.is_empty()
        {
            self.cover.tries += 1;
            self.cover.artwork = read_thumbnail(props).and_then(Artwork::from_bytes);
        }
        self.cover.artwork.clone()
    }
}

/// What Spotify told SMTC about a track, for the log: shows which fields it leaves empty.
fn track_line(s: &Snapshot) -> String {
    let n = |v: Option<u32>| v.map_or("?".to_string(), |v| v.to_string());
    let shuffle = s.shuffle.map_or("?".to_string(), |v| v.to_string());
    let repeat = s.repeat.map_or("?", Repeat::wire);
    format!(
        "track {:?} by {:?}, album {:?} by {:?}, number {}/{}, genres [{}], shuffle {shuffle}, repeat {repeat}, {} s",
        s.title,
        s.artist,
        s.album,
        s.album_artist,
        n(s.track_number),
        n(s.album_track_count),
        s.genres.join(", "),
        s.length.as_secs()
    )
}

fn err(e: windows::core::Error) -> String {
    e.message()
}

/// SMTC answers `false` when Spotify did not take the command. That is a failure: an `ok` ack to
/// the backend must mean Spotify accepted it.
fn accepted(taken: bool) -> Result<(), String> {
    if taken {
        Ok(())
    } else {
        Err("Spotify did not accept the command".into())
    }
}

/// Spotify's AppUserModelId: `Spotify.exe` for the installer build, a `SpotifyAB...` package for the Store one.
fn is_spotify_app(id: &str) -> bool {
    id.to_lowercase().contains("spotify")
}

fn playback_from(status: Status) -> Playback {
    match status {
        Status::Playing => Playback::Playing,
        Status::Paused => Playback::Paused,
        _ => Playback::Stopped,
    }
}

/// SMTC reports 0 (or less) for a count it does not know.
fn count(n: i32) -> Option<u32> {
    u32::try_from(n).ok().filter(|n| *n > 0)
}

fn repeat_from(mode: MediaPlaybackAutoRepeatMode) -> Repeat {
    match mode {
        MediaPlaybackAutoRepeatMode::Track => Repeat::Track,
        MediaPlaybackAutoRepeatMode::List => Repeat::List,
        _ => Repeat::None,
    }
}

/// A timeline value: 100 ns ticks, never negative.
fn ticks(t: TimeSpan) -> Duration {
    Duration::from_nanos(t.Duration.max(0) as u64 * 100)
}

/// Time elapsed since Spotify last updated the timeline. `DateTime` is 100 ns ticks since
/// 1601-01-01; the Unix epoch is 11644473600 s later.
fn since_update(updated: DateTime, now: SystemTime) -> Duration {
    let updated = Duration::from_nanos(updated.UniversalTime.max(0) as u64 * 100);
    let now =
        now.duration_since(UNIX_EPOCH).unwrap_or_default() + Duration::from_secs(11_644_473_600);
    now.saturating_sub(updated)
}

fn spotify_session() -> Result<Option<Session>, String> {
    let manager = Manager::RequestAsync().map_err(err)?.join().map_err(err)?;
    let sessions = manager.GetSessions().map_err(err)?;
    for session in sessions {
        let id = session.SourceAppUserModelId().map_err(err)?.to_string();
        if is_spotify_app(&id) {
            return Ok(Some(session));
        }
    }
    Ok(None)
}

impl Backend for Smtc {
    fn snapshot(&mut self) -> Result<Snapshot, String> {
        let Some(session) = spotify_session()? else {
            self.uris.forget();
            return Ok(Snapshot::not_running());
        };
        let props = session
            .TryGetMediaPropertiesAsync()
            .map_err(err)?
            .join()
            .map_err(err)?;
        let info = session.GetPlaybackInfo().map_err(err)?;
        let status = info.PlaybackStatus().map_err(err)?;
        // Not every app reports the modes: a missing value is "unknown", not an error.
        let shuffle = info.IsShuffleActive().and_then(|v| v.Value()).ok();
        let repeat = info
            .AutoRepeatMode()
            .and_then(|v| v.Value())
            .ok()
            .map(repeat_from);
        let playback = playback_from(status);
        let timeline = session.GetTimelineProperties().map_err(err)?;
        let length = ticks(timeline.EndTime().map_err(err)?)
            .saturating_sub(ticks(timeline.StartTime().map_err(err)?));
        let reported = ticks(timeline.Position().map_err(err)?);
        let elapsed = since_update(timeline.LastUpdatedTime().map_err(err)?, SystemTime::now());
        let position = current_position(reported, elapsed, playback, length);
        let title = props.Title().map_err(err)?.to_string();
        let artist = props.Artist().map_err(err)?.to_string();
        let album = props.AlbumTitle().map_err(err)?.to_string();
        let album_artist = props.AlbumArtist().map_err(err)?.to_string();
        let track_number = count(props.TrackNumber().map_err(err)?);
        let album_track_count = count(props.AlbumTrackCount().map_err(err)?);
        let genres = props
            .Genres()
            .map(|g| g.into_iter().map(|g| g.to_string()).collect())
            .unwrap_or_default();
        let artwork = self.cover_for(&props, (title.clone(), artist.clone(), album.clone()));
        let uri = self.uris.observe(
            Identity {
                title: title.clone(),
                artist: artist.clone(),
                album: album.clone(),
                seconds: length.as_secs(),
            },
            Instant::now(),
        );
        let snapshot = Snapshot {
            running: true,
            position,
            length,
            artwork,
            uri,
            title,
            artist,
            album,
            album_artist,
            track_number,
            album_track_count,
            genres,
            shuffle,
            repeat,
            playback,
            volume: volume::get().unwrap_or(None),
            ..Snapshot::default()
        };
        let track = (
            snapshot.title.clone(),
            snapshot.artist.clone(),
            snapshot.album.clone(),
        );
        if !track.0.is_empty() && track != self.logged {
            crate::log::info(track_line(&snapshot));
            self.logged = track;
        }
        Ok(snapshot)
    }

    fn toggle_play_pause(&mut self) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        accepted(
            session
                .TryTogglePlayPauseAsync()
                .map_err(err)?
                .join()
                .map_err(err)?,
        )
    }

    /// Spotify's own pause: asking a paused Spotify to pause changes nothing.
    fn pause(&mut self) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        accepted(session.TryPauseAsync().map_err(err)?.join().map_err(err)?)
    }

    fn pause_is_idempotent(&self) -> bool {
        true
    }

    fn verifies_start(&self) -> bool {
        true
    }

    fn play(&mut self) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        accepted(session.TryPlayAsync().map_err(err)?.join().map_err(err)?)
    }

    /// Moves in the current track; `TryChangePlaybackPositionAsync` counts in 100 ns ticks.
    fn seek(&mut self, to: Duration) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        let ticks = i64::try_from(to.as_nanos() / 100).unwrap_or(i64::MAX);
        accepted(
            session
                .TryChangePlaybackPositionAsync(ticks)
                .map_err(err)?
                .join()
                .map_err(err)?,
        )
    }

    fn next(&mut self) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        accepted(
            session
                .TrySkipNextAsync()
                .map_err(err)?
                .join()
                .map_err(err)?,
        )
    }

    fn previous(&mut self) -> Result<(), String> {
        let session = spotify_session()?.ok_or("Spotify is not running")?;
        accepted(
            session
                .TrySkipPreviousAsync()
                .map_err(err)?
                .join()
                .map_err(err)?,
        )
    }

    fn set_volume(&mut self, volume: f32) -> Result<(), String> {
        volume::set(volume)
    }

    fn play_uri(&mut self, uri: &str) -> Result<(), String> {
        // Hands the URI to the registered spotify: handler, i.e. the local desktop app.
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        std::process::Command::new("rundll32")
            .args(["url.dll,FileProtocolHandler", &autoplay_uri(uri)])
            .creation_flags(CREATE_NO_WINDOW)
            .spawn()
            .map(drop)
            .map_err(|e| e.to_string())?;
        self.uris.commanded(uri.to_string(), Instant::now());
        Ok(())
    }
}

#[cfg(test)]
mod tests;
