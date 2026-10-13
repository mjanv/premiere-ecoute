use super::*;

fn temp(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!(
        "premiere-ecoute-player-test-{}-{name}",
        std::process::id()
    ))
}

#[test]
fn an_address_is_saved_trimmed_and_loaded_back_and_can_be_replaced() {
    let dir = temp("roundtrip");
    assert_eq!(load_from(&dir), None);
    save_to(&dir, "  http://localhost:4000 \n").unwrap();
    assert_eq!(load_from(&dir).as_deref(), Some("http://localhost:4000"));
    save_to(&dir, "https://premiere-ecoute.fr").unwrap();
    assert_eq!(
        load_from(&dir).as_deref(),
        Some("https://premiere-ecoute.fr")
    );
    assert!(!dir.join("server.txt.tmp").exists());
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn an_empty_or_blank_file_means_nothing_was_chosen() {
    let dir = temp("blank");
    save_to(&dir, "   ").unwrap();
    assert_eq!(load_from(&dir), None);
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn the_environment_wins_over_the_saved_address_and_blanks_are_skipped() {
    assert_eq!(
        resolve(Some("http://a"), Some("http://b")).as_deref(),
        Some("http://a")
    );
    assert_eq!(resolve(None, Some("http://b")).as_deref(), Some("http://b"));
    assert_eq!(
        resolve(Some("  "), Some("http://b")).as_deref(),
        Some("http://b")
    );
    assert_eq!(resolve(None, None), None);
}
