use super::*;

#[test]
fn a_line_has_a_utc_timestamp_a_level_and_the_message() {
    // 2026-10-21 20:30:05 UTC
    assert_eq!(
        line(1_792_614_605, "INFO", "linked"),
        "2026-10-21T20:30:05Z INFO linked"
    );
}

#[test]
fn the_epoch_and_a_leap_day_format_correctly() {
    assert_eq!(timestamp(0), "1970-01-01T00:00:00Z");
    // 2024-02-29 12:00:00 UTC
    assert_eq!(timestamp(1_709_208_000), "2024-02-29T12:00:00Z");
}

#[test]
fn a_message_never_breaks_the_one_line_per_entry_rule() {
    let l = line(0, "WARN", "first\nsecond\r\nthird");
    assert_eq!(l.lines().count(), 1);
    assert!(l.ends_with("first | second | third"));
}

#[test]
fn the_file_is_rotated_once_it_is_over_a_megabyte() {
    assert!(!needs_rotation(1024 * 1024));
    assert!(needs_rotation(1024 * 1024 + 1));
}

#[test]
fn the_log_lives_in_the_local_app_data_folder() {
    let dir = dir_in(Some("C:\\Users\\Me\\AppData\\Local".into())).unwrap();
    assert!(dir.ends_with("premiere-ecoute-player"));
    assert!(dir.starts_with("C:\\Users\\Me\\AppData\\Local"));
    assert_eq!(dir_in(None), None);
}

#[test]
fn a_panic_is_described_with_its_message_and_place() {
    assert_eq!(
        panic_line("boom", Some(("src/a.rs", 3))),
        "panic: boom at src/a.rs:3"
    );
    assert_eq!(panic_line("boom", None), "panic: boom");
}

#[test]
fn logging_before_init_is_a_silent_no_op() {
    info("nobody listens");
    warn("still nobody");
}
