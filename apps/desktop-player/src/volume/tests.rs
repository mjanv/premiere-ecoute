use super::*;

#[test]
fn only_the_spotify_executable_is_matched() {
    assert!(is_spotify_exe(
        r"C:\Users\me\AppData\Roaming\Spotify\Spotify.exe"
    ));
    assert!(is_spotify_exe(r"c:\program files\spotify\SPOTIFY.EXE"));
    assert!(!is_spotify_exe(r"C:\tools\notspotify.exe"));
    assert!(!is_spotify_exe(r"C:\Windows\explorer.exe"));
    assert!(!is_spotify_exe("spotify.exe"));
    assert!(!is_spotify_exe(""));
}

/// Read-only: with no Spotify audio session, no audio device (CI) or Spotify playing, it answers
/// without panicking, and a volume is always a fraction.
#[test]
fn reading_the_volume_never_panics_and_stays_a_fraction() {
    if let Ok(Some(v)) = get() {
        assert!((0.0..=1.0).contains(&v), "{v}");
    }
}
