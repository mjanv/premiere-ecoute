//! The status light on the app's taskbar button (an overlay badge), visible while the window is
//! minimized behind other software. Windows draws it over the corner of the button.

use crate::light::Light;
use gpui_kit::Window;
use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use std::ffi::c_void;
use windows::Win32::Foundation::HWND;
use windows::Win32::Graphics::Gdi::{CreateBitmap, DeleteObject, HGDIOBJ};
use windows::Win32::System::Com::{CLSCTX_INPROC_SERVER, CoCreateInstance};
use windows::Win32::UI::Shell::{ITaskbarList3, TaskbarList};
use windows::Win32::UI::WindowsAndMessaging::{CreateIconIndirect, DestroyIcon, HICON, ICONINFO};
use windows::core::HSTRING;

/// Overlay icons are drawn at 16x16 logical pixels.
const SIZE: usize = 16;
/// Dark rim that keeps the dot readable on light and dark taskbars.
const RING: [u8; 3] = [0x14, 0x14, 0x14];

/// BGRA pixels of a filled circle with a dark rim, anti-aliased by coverage. Straight (not
/// premultiplied) alpha, as `CreateIconIndirect` expects.
fn dot_pixels(rgb: [u8; 3]) -> Vec<u8> {
    let centre = (SIZE as f32 - 1.0) / 2.0;
    let radius = SIZE as f32 / 2.0 - 0.5;
    let rim = 1.5;
    let mut out = Vec::with_capacity(SIZE * SIZE * 4);
    for y in 0..SIZE {
        for x in 0..SIZE {
            let d = ((x as f32 - centre).powi(2) + (y as f32 - centre).powi(2)).sqrt();
            let alpha = ((radius - d + 0.5).clamp(0.0, 1.0) * 255.0).round() as u8;
            let [r, g, b] = if d > radius - rim { RING } else { rgb };
            out.extend_from_slice(&[b, g, r, alpha]);
        }
    }
    out
}

pub fn icon(light: Light) -> Option<HICON> {
    let pixels = dot_pixels(light.rgb());
    // SAFETY: `pixels` holds SIZE*SIZE 32-bit pixels and outlives the call, which copies them.
    let color = unsafe {
        CreateBitmap(
            SIZE as i32,
            SIZE as i32,
            1,
            32,
            Some(pixels.as_ptr().cast::<c_void>()),
        )
    };
    // SAFETY: no pixel data: a blank 1-bit mask, which a 32-bit colour bitmap's alpha overrides.
    let mask = unsafe { CreateBitmap(SIZE as i32, SIZE as i32, 1, 1, None) };
    let info = ICONINFO {
        fIcon: true.into(),
        xHotspot: 0,
        yHotspot: 0,
        hbmMask: mask,
        hbmColor: color,
    };
    // SAFETY: both bitmaps are valid GDI objects created above.
    let icon = unsafe { CreateIconIndirect(&info) }.ok();
    // SAFETY: the icon owns copies of the bitmaps, ours are no longer needed.
    unsafe {
        let _ = DeleteObject(HGDIOBJ(color.0));
        let _ = DeleteObject(HGDIOBJ(mask.0));
    }
    icon
}

/// Draws the light on the window's taskbar button. Create and use it on the UI thread: the taskbar
/// COM object lives in that thread's apartment.
pub struct Badge {
    hwnd: HWND,
    taskbar: ITaskbarList3,
    shown: Option<Light>,
}

/// The native handle of a GPUI window.
pub fn hwnd_of(window: &Window) -> Option<HWND> {
    let RawWindowHandle::Win32(handle) = HasWindowHandle::window_handle(window).ok()?.as_raw()
    else {
        return None;
    };
    Some(HWND(handle.hwnd.get() as *mut c_void))
}

impl Badge {
    pub fn for_window(window: &Window) -> Option<Self> {
        let hwnd = hwnd_of(window)?;
        // SAFETY: plain COM activation; the UI thread has COM initialised by the window system.
        let taskbar: ITaskbarList3 =
            unsafe { CoCreateInstance(&TaskbarList, None, CLSCTX_INPROC_SERVER) }.ok()?;
        // SAFETY: the object was just created.
        unsafe { taskbar.HrInit() }.ok()?;
        Some(Self {
            hwnd,
            taskbar,
            shown: None,
        })
    }

    /// Sets the badge when the light changed. A failure (the taskbar button may not exist yet) is
    /// retried by the next call.
    pub fn show(&mut self, light: Light) {
        if self.shown == Some(light) {
            return;
        }
        let Some(icon) = icon(light) else {
            return;
        };
        let description = HSTRING::from(light.description());
        // SAFETY: `hwnd` is the app's window, `icon` and `description` are valid for the call.
        let set = unsafe { self.taskbar.SetOverlayIcon(self.hwnd, icon, &description) };
        // SAFETY: the taskbar copies the icon, ours is no longer needed.
        unsafe {
            let _ = DestroyIcon(icon);
        }
        if set.is_ok() {
            self.shown = Some(light);
        }
    }
}

#[cfg(test)]
mod tests;
