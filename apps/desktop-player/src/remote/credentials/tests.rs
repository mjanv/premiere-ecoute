use super::*;

#[test]
fn the_windows_credential_manager_round_trips_a_token_and_forgets_it() {
    let store = WindowsStore::for_server(&format!("http://test.invalid/{}", std::process::id()));
    assert_eq!(store.load(), Ok(None));
    store.save("refresh-1").unwrap();
    assert_eq!(store.load(), Ok(Some("refresh-1".into())));
    store.save("refresh-2").unwrap(); // rotation overwrites
    assert_eq!(store.load(), Ok(Some("refresh-2".into())));
    store.delete().unwrap();
    assert_eq!(store.load(), Ok(None));
    store.delete().unwrap(); // deleting twice is fine
}
