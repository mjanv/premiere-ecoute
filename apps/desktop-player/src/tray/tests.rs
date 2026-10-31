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

#[test]
fn every_light_survives_the_round_trip_through_its_code() {
    for light in [Light::Green, Light::Amber, Light::Red, Light::Grey] {
        assert_eq!(light_from_code(light_code(light)), light);
    }
}

#[test]
fn an_unknown_code_is_the_neutral_light() {
    assert_eq!(light_from_code(200), Light::Grey);
}

#[test]
fn only_the_registered_taskbar_message_means_the_taskbar_came_back() {
    assert!(is_taskbar_created(0xC123, 0xC123));
    assert!(!is_taskbar_created(0xC124, 0xC123));
    // Registration failed: no message is ever taken for it, not even 0.
    assert!(!is_taskbar_created(0, 0));
}
