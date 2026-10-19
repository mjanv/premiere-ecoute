//! Reads and controls the local Spotify app through the Windows System Media
//! Transport Controls (the API behind the volume/media flyout).

use crate::artwork::Artwork;
use crate::identity::{Identity, UriTracker};
use crate::player::{Backend, Playback, Snapshot, autoplay_uri, current_position};
use crate::volume;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use windows::Media::Control::{
    GlobalSystemMediaTransportControlsSession as Session,
    GlobalSystemMediaTransportControlsSessionManager as Manager,
    GlobalSystemMediaTransportControlsSessionMediaProperties,
    GlobalSystemMediaTransportControlsSessionPlaybackStatus as Status,
};
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

fn spotify_session() -> Result<Option<Session>, String> {
    let manager = Manager::RequestAsync().map_err(err)?.join().map_err(err)?;
    let sessions = manager.GetSessions().map_err(err)?;
    for session in sessions {
        let id = session.SourceAppUserModelId().map_err(err)?.to_string();
        if id.to_lowercase().contains("spotify") {
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
        let status = session
            .GetPlaybackInfo()
            .map_err(err)?
            .PlaybackStatus()
            .map_err(err)?;
        let playback = match status {
            Status::Playing => Playback::Playing,
            Status::Paused => Playback::Paused,
            _ => Playback::Stopped,
        };
        let timeline = session.GetTimelineProperties().map_err(err)?;
        let ticks =
            |t: windows::Foundation::TimeSpan| Duration::from_nanos(t.Duration.max(0) as u64 * 100);
        let length = ticks(timeline.EndTime().map_err(err)?)
            .saturating_sub(ticks(timeline.StartTime().map_err(err)?));
        let reported = ticks(timeline.Position().map_err(err)?);
        // DateTime is 100ns ticks since 1601-01-01; the Unix epoch is 11644473600s later.
        let updated = Duration::from_nanos(
            timeline
                .LastUpdatedTime()
                .map_err(err)?
                .UniversalTime
                .max(0) as u64
                * 100,
        );
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            + Duration::from_secs(11_644_473_600);
        let position = current_position(reported, now.saturating_sub(updated), playback, length);
        let title = props.Title().map_err(err)?.to_string();
        let artist = props.Artist().map_err(err)?.to_string();
        let album = props.AlbumTitle().map_err(err)?.to_string();
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
        Ok(Snapshot {
            running: true,
            position,
            length,
            artwork,
            uri,
            title,
            artist,
            album,
            playback,
            volume: volume::get().unwrap_or(None),
            ..Snapshot::default()
        })
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
