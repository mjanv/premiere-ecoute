//! The notification-area icon: the status light, and the place the window goes when minimized.
//!
//! Minimizing hides the window and its taskbar button; a left click on the icon brings it back. The
//! icon is owned by its own thread, with a hidden window and a message loop, so it never depends
//! on the UI thread's loop. It talks back through a channel the UI thread polls.

mod promote;

use crate::light::Light;
use crate::taskbar;
use std::ffi::c_void;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicU8, AtomicU32, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use windows::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows::Win32::System::LibraryLoader::GetModuleHandleW;
use windows::Win32::UI::Shell::{
    NIF_ICON, NIF_MESSAGE, NIF_TIP, NIM_ADD, NIM_DELETE, NIM_MODIFY, NOTIFYICONDATAW,
    Shell_NotifyIconW,
};
use windows::Win32::UI::WindowsAndMessaging::{
    AppendMenuW, CreatePopupMenu, CreateWindowExW, DefWindowProcW, DestroyIcon, DestroyMenu,
    DispatchMessageW, GetCursorPos, GetMessageW, IsIconic, MF_STRING, MSG, PostMessageW,
    PostQuitMessage, RegisterClassW, RegisterWindowMessageW, SW_HIDE, SW_RESTORE,
    SetForegroundWindow, ShowWindow, TPM_RETURNCMD, TPM_RIGHTBUTTON, TrackPopupMenu,
    TranslateMessage, WM_CLOSE, WM_DESTROY, WM_LBUTTONDBLCLK, WM_LBUTTONUP, WM_RBUTTONUP,
    WNDCLASSW, WS_EX_TOOLWINDOW, WS_POPUP,
};
use windows::core::{PCWSTR, w};

const WM_APP: u32 = 0x8000;
/// What the shell sends to the hidden window about the icon.
const CALLBACK: u32 = WM_APP + 1;
const ICON_ID: u32 = 1;
const ID_OPEN: usize = 1;
const ID_QUIT: usize = 2;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Event {
    Open,
    Quit,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Click {
    Open,
    Menu,
    Ignore,
}

/// The shell puts the mouse message in the low word of the callback's `lParam`.
fn click(lparam: u32) -> Click {
    match lparam & 0xffff {
        WM_LBUTTONUP | WM_LBUTTONDBLCLK => Click::Open,
        WM_RBUTTONUP => Click::Menu,
        _ => Click::Ignore,
    }
}

fn menu_event(command: usize) -> Option<Event> {
    match command {
        ID_OPEN => Some(Event::Open),
        ID_QUIT => Some(Event::Quit),
        _ => None,
    }
}

fn tooltip(light: Light) -> String {
    format!("Premiere Ecoute: {}", light.description())
}

/// The light the icon shows now, kept for the procedure: when Explorer restarts the icon is added
/// again with it.
static CURRENT_LIGHT: AtomicU8 = AtomicU8::new(0);
/// The id Windows gave the "TaskbarCreated" message, 0 until registered.
static TASKBAR_CREATED: AtomicU32 = AtomicU32::new(0);

fn light_code(light: Light) -> u8 {
    match light {
        Light::Grey => 0,
        Light::Green => 1,
        Light::Amber => 2,
        Light::Red => 3,
    }
}

fn light_from_code(code: u8) -> Light {
    match code {
        1 => Light::Green,
        2 => Light::Amber,
        3 => Light::Red,
        _ => Light::Grey,
    }
}

/// Windows sends a registered message to every top-level window when the taskbar is created again
/// (Explorer restarted): the icons it had are gone and have to be added again.
fn is_taskbar_created(message: u32, registered: u32) -> bool {
    registered != 0 && message == registered
}

/// Adds the icon, with its callback message and the light `light`. Returns whether the shell took it.
fn add_icon(hwnd: HWND, light: Light) -> bool {
    let mut nid = data(hwnd);
    nid.uFlags = NIF_MESSAGE;
    nid.uCallbackMessage = CALLBACK;
    let icon = fill(&mut nid, light);
    let added = notify(NIM_ADD, &nid);
    if let Some(icon) = icon {
        // SAFETY: the shell copied the icon.
        let _ = unsafe { DestroyIcon(icon) };
    }
    added
}

/// Where the hidden window's procedure sends what the user chose.
static EVENTS: OnceLock<Sender<Event>> = OnceLock::new();

fn emit(event: Event) {
    if let Some(events) = EVENTS.get() {
        let _ = events.send(event);
    }
}

fn data(hwnd: HWND) -> NOTIFYICONDATAW {
    NOTIFYICONDATAW {
        cbSize: size_of::<NOTIFYICONDATAW>() as u32,
        hWnd: hwnd,
        uID: ICON_ID,
        ..Default::default()
    }
}

fn fill(
    nid: &mut NOTIFYICONDATAW,
    light: Light,
) -> Option<windows::Win32::UI::WindowsAndMessaging::HICON> {
    let icon = taskbar::icon(light)?;
    nid.uFlags |= NIF_ICON | NIF_TIP;
    nid.hIcon = icon;
    // The shell keeps room for 127 characters and a terminating zero; `Default` zeroed the rest.
    for (slot, unit) in nid
        .szTip
        .iter_mut()
        .zip(tooltip(light).encode_utf16().take(127))
    {
        *slot = unit;
    }
    Some(icon)
}

fn notify(message: windows::Win32::UI::Shell::NOTIFY_ICON_MESSAGE, nid: &NOTIFYICONDATAW) -> bool {
    // SAFETY: `nid` is fully initialised, with the size the shell checks, and lives for the call.
    unsafe { Shell_NotifyIconW(message, nid) }.as_bool()
}

fn show_menu(hwnd: HWND) {
    // SAFETY: plain menu calls on the thread that owns `hwnd`; the menu is destroyed before return.
    unsafe {
        let Ok(menu) = CreatePopupMenu() else {
            return;
        };
        let _ = AppendMenuW(menu, MF_STRING, ID_OPEN, w!("Open"));
        let _ = AppendMenuW(menu, MF_STRING, ID_QUIT, w!("Quit"));
        let mut at = Default::default();
        let _ = GetCursorPos(&mut at);
        // Without this the menu stays open when the user clicks elsewhere.
        let _ = SetForegroundWindow(hwnd);
        let chosen = TrackPopupMenu(
            menu,
            TPM_RETURNCMD | TPM_RIGHTBUTTON,
            at.x,
            at.y,
            None,
            hwnd,
            None,
        );
        let _ = DestroyMenu(menu);
        if let Some(event) = menu_event(chosen.0 as usize) {
            emit(event);
        }
    }
}

extern "system" fn procedure(hwnd: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    match message {
        CALLBACK => {
            match click(lparam.0 as u32) {
                Click::Open => emit(Event::Open),
                Click::Menu => show_menu(hwnd),
                Click::Ignore => {}
            }
            LRESULT(0)
        }
        m if is_taskbar_created(m, TASKBAR_CREATED.load(Ordering::Relaxed)) => {
            // Explorer restarted: the icon is gone. Adding one that exists fails, which is harmless.
            add_icon(hwnd, light_from_code(CURRENT_LIGHT.load(Ordering::Relaxed)));
            LRESULT(0)
        }
        WM_DESTROY => {
            notify(NIM_DELETE, &data(hwnd));
            // SAFETY: ends this thread's message loop.
            unsafe { PostQuitMessage(0) };
            LRESULT(0)
        }
        // SAFETY: the default handling for everything else.
        _ => unsafe { DefWindowProcW(hwnd, message, wparam, lparam) },
    }
}

/// Creates the hidden window and the icon, then serves messages until the window is closed.
fn run(ready: Sender<Option<isize>>) {
    // SAFETY: standard window-class registration and creation on this thread; the class name and
    // the procedure outlive the program.
    let hwnd = unsafe {
        let module = GetModuleHandleW(None).ok();
        let class = WNDCLASSW {
            lpfnWndProc: Some(procedure),
            hInstance: module.map(|m| m.into()).unwrap_or_default(),
            lpszClassName: w!("PremiereEcouteTray"),
            ..Default::default()
        };
        RegisterClassW(&class);
        CreateWindowExW(
            WS_EX_TOOLWINDOW,
            w!("PremiereEcouteTray"),
            PCWSTR::null(),
            WS_POPUP,
            0,
            0,
            0,
            0,
            None,
            None,
            module.map(|m| m.into()),
            None,
        )
    };
    let Ok(hwnd) = hwnd else {
        let _ = ready.send(None);
        return;
    };
    // SAFETY: registers a message name with Windows; the returned id is valid for the session.
    let created = unsafe { RegisterWindowMessageW(w!("TaskbarCreated")) };
    TASKBAR_CREATED.store(created, Ordering::Relaxed);
    let added = add_icon(hwnd, Light::Grey);
    let _ = ready.send(added.then_some(hwnd.0 as isize));
    if !added {
        return;
    }
    let mut msg = MSG::default();
    // SAFETY: the usual message loop; it ends when `PostQuitMessage` is called from `WM_DESTROY`.
    unsafe {
        while GetMessageW(&mut msg, None, 0, 0).as_bool() {
            let _ = TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
}

/// The icon and the window it hides. Use it from the UI thread.
pub struct Tray {
    icon_window: HWND,
    main: HWND,
    events: Receiver<Event>,
    shown: Option<Light>,
}

impl Tray {
    /// Puts the icon in the notification area. `None` when the shell refuses.
    pub fn start(main: HWND) -> Option<Self> {
        let (tx, events) = channel();
        EVENTS.set(tx).ok()?;
        let (ready, started) = channel();
        std::thread::Builder::new()
            .name("tray".into())
            .spawn(move || run(ready))
            .ok()?;
        // Without this Windows 11 hides the icon in the "^" overflow.
        let _ = std::thread::Builder::new()
            .name("tray-promote".into())
            .spawn(promote::run);
        let icon_window = HWND(started.recv().ok()?? as *mut c_void);
        Some(Self {
            icon_window,
            main,
            events,
            shown: None,
        })
    }

    /// Changes the icon colour and tooltip when the light changed.
    pub fn set_light(&mut self, light: Light) {
        if self.shown == Some(light) {
            return;
        }
        let mut nid = data(self.icon_window);
        let Some(icon) = fill(&mut nid, light) else {
            return;
        };
        if notify(NIM_MODIFY, &nid) {
            self.shown = Some(light);
            CURRENT_LIGHT.store(light_code(light), Ordering::Relaxed);
        }
        // SAFETY: the shell copied the icon.
        let _ = unsafe { DestroyIcon(icon) };
    }

    /// Hides a minimized window and handles the icon's clicks. Returns `Quit` when the user chose it.
    pub fn poll(&mut self) -> Option<Event> {
        // SAFETY: `main` is this app's window, used from the thread that owns it.
        unsafe {
            if IsIconic(self.main).as_bool() {
                let _ = ShowWindow(self.main, SW_HIDE);
            }
        }
        while let Ok(event) = self.events.try_recv() {
            match event {
                Event::Open => {
                    // SAFETY: as above.
                    unsafe {
                        let _ = ShowWindow(self.main, SW_RESTORE);
                        let _ = SetForegroundWindow(self.main);
                    }
                }
                Event::Quit => return Some(Event::Quit),
            }
        }
        None
    }
}

impl Drop for Tray {
    fn drop(&mut self) {
        // SAFETY: asks the tray thread to remove the icon and stop.
        let _ = unsafe { PostMessageW(Some(self.icon_window), WM_CLOSE, WPARAM(0), LPARAM(0)) };
    }
}

#[cfg(test)]
mod tests;
