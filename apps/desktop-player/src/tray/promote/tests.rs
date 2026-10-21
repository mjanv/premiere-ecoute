use super::*;

#[test]
fn an_icon_nobody_decided_about_is_promoted() {
    assert!(should_promote(None));
}

#[test]
fn a_choice_already_made_is_left_alone() {
    // 1: already promoted. 0: the user hid it from the taskbar, it must stay hidden.
    assert!(!should_promote(Some(1)));
    assert!(!should_promote(Some(0)));
}

#[test]
fn exe_paths_compare_without_case() {
    assert!(same_exe(
        r"C:\Users\Me\pep-dev.exe",
        r"c:\users\me\PEP-DEV.exe"
    ));
}

#[test]
fn the_long_path_prefix_is_ignored() {
    assert!(same_exe(
        r"\\?\C:\Users\Me\pep-dev.exe",
        r"C:\Users\Me\pep-dev.exe"
    ));
}

#[test]
fn another_exe_is_not_ours() {
    assert!(!same_exe(r"C:\a\player.exe", r"C:\b\player.exe"));
    assert!(!same_exe("", r"C:\a\player.exe"));
}
