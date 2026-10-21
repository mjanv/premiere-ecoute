use super::*;
use windows::Win32::UI::WindowsAndMessaging::WM_MOUSEMOVE;

#[test]
fn a_left_click_or_double_click_opens_the_window() {
    assert_eq!(click(WM_LBUTTONUP), Click::Open);
    assert_eq!(click(WM_LBUTTONDBLCLK), Click::Open);
}

#[test]
fn a_right_click_opens_the_menu() {
    assert_eq!(click(WM_RBUTTONUP), Click::Menu);
}

#[test]
fn other_mouse_messages_are_ignored() {
    assert_eq!(click(WM_MOUSEMOVE), Click::Ignore);
    assert_eq!(click(0), Click::Ignore);
}

#[test]
fn only_the_low_word_of_the_callback_parameter_is_the_message() {
    // With the default tray behaviour the icon id may ride in the high word.
    assert_eq!(click(0x0001_0000 | WM_LBUTTONUP), Click::Open);
}

#[test]
fn the_menu_commands_map_to_events() {
    assert_eq!(menu_event(ID_OPEN), Some(Event::Open));
    assert_eq!(menu_event(ID_QUIT), Some(Event::Quit));
    assert_eq!(menu_event(0), None);
}

#[test]
fn the_tooltip_names_the_app_and_the_state_and_fits_the_shell_limit() {
    for light in [Light::Green, Light::Amber, Light::Red, Light::Grey] {
        let tip = tooltip(light);
        assert!(tip.starts_with("Premiere Ecoute"));
        assert!(tip.contains(light.description()));
        assert!(tip.encode_utf16().count() < 128, "{tip}");
    }
}
