use super::*;

/// Needs Spotify playing on this PC: run with `--ignored` while a track plays.
#[test]
#[ignore = "needs Spotify playing"]
fn captures_sound_from_spotify_while_it_plays() {
    // SAFETY: first COM call on this test thread.
    unsafe {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED);
    }
    let pid = volume::spotify_pid()
        .unwrap()
        .expect("Spotify has an audio session: play something first");
    let capture = open(pid).expect("per-process loopback opens");
    let mut loudest = 0.0f32;
    let mut mono = Vec::new();
    for _ in 0..80 {
        mono.clear();
        capture.drain(&mut mono).unwrap();
        loudest = mono.iter().fold(loudest, |m, s| m.max(s.abs()));
    }
    assert!(
        loudest > 0.001,
        "only silence was captured (is Spotify playing?): {loudest}"
    );
}
