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
    let default = "https://default";
    assert_eq!(
        resolve(Some("http://a"), Some("http://b"), default),
        "http://a"
    );
    assert_eq!(resolve(None, Some("http://b"), default), "http://b");
    assert_eq!(resolve(Some("  "), Some("http://b"), default), "http://b");
}

#[test]
fn the_built_in_server_is_the_fallback() {
    assert_eq!(resolve(None, None, "https://default"), "https://default");
    assert_eq!(
        resolve(Some(" "), Some(""), "https://default"),
        "https://default"
    );
}

#[test]
fn the_built_in_server_matches_the_build_flavour() {
    if cfg!(feature = "dev-server") {
        assert_eq!(DEFAULT_SERVER, "http://localhost:4000");
    } else {
        assert_eq!(DEFAULT_SERVER, "https://premiere-ecoute.fr");
    }
}

#[test]
fn a_saved_address_can_be_forgotten_and_nothing_is_loaded_after() {
    let dir = std::env::temp_dir().join(format!("pep-config-forget-{}", std::process::id()));
    save_to(&dir, "https://one.example").unwrap();
    assert_eq!(load_from(&dir).as_deref(), Some("https://one.example"));
    forget_from(&dir).unwrap();
    assert_eq!(load_from(&dir), None);
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn forgetting_when_nothing_was_saved_is_not_an_error() {
    let dir = std::env::temp_dir().join(format!("pep-config-nothing-{}", std::process::id()));
    assert!(forget_from(&dir).is_ok());
}

#[test]
fn a_forgotten_address_can_be_saved_again() {
    let dir = std::env::temp_dir().join(format!("pep-config-again-{}", std::process::id()));
    save_to(&dir, "https://one.example").unwrap();
    forget_from(&dir).unwrap();
    save_to(&dir, "https://two.example").unwrap();
    assert_eq!(load_from(&dir).as_deref(), Some("https://two.example"));
    let _ = std::fs::remove_dir_all(&dir);
}
