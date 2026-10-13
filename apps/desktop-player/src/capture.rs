//! Spotify's own sound, through Windows per-process loopback capture (Windows 10 2004 or newer):
//! only Spotify's audio, never alerts or other apps, and no microphone. The samples go straight to
//! the scope, which keeps the last ~25 ms for drawing; nothing is recorded.

use crate::player::lock;
use crate::volume;
use crate::waveform::{Scope, mono_from_i16_stereo};
use std::mem::ManuallyDrop;
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use windows::Win32::Foundation::{CloseHandle, HANDLE};
use windows::Win32::Media::Audio::{
    AUDCLNT_BUFFERFLAGS_SILENT, AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
    AUDCLNT_STREAMFLAGS_LOOPBACK, AUDIOCLIENT_ACTIVATION_PARAMS,
    AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK, AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS,
    ActivateAudioInterfaceAsync, IActivateAudioInterfaceAsyncOperation,
    IActivateAudioInterfaceCompletionHandler, IActivateAudioInterfaceCompletionHandler_Impl,
    IAudioCaptureClient, IAudioClient, PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE,
    VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK, WAVE_FORMAT_PCM, WAVEFORMATEX,
};
use windows::Win32::System::Com::StructuredStorage::{
    PROPVARIANT, PROPVARIANT_0, PROPVARIANT_0_0, PROPVARIANT_0_0_0,
};
use windows::Win32::System::Com::{
    BLOB, COINIT_MULTITHREADED, CoInitializeEx, IAgileObject, IAgileObject_Impl,
};
use windows::Win32::System::Threading::{CreateEventW, WaitForSingleObject};
use windows::Win32::System::Variant::VT_BLOB;
use windows::core::{HRESULT, IUnknown, Interface, Ref, implement};

const RATE: u32 = 48_000;
const CHANNELS: u16 = 2;
/// How often the capture is drained: one pass, and one update of the scope, every 25 ms.
const PASS: Duration = Duration::from_millis(25);
const ACTIVATION_TIMEOUT: Duration = Duration::from_secs(5);
/// How often to check that the capture still follows Spotify's audio process.
const PID_CHECK: Duration = Duration::from_secs(2);
const RETRY: Duration = Duration::from_secs(2);

fn err(e: windows::core::Error) -> String {
    e.message()
}

/// Windows calls this when the activation finishes; it only wakes the waiting thread.
#[implement(IActivateAudioInterfaceCompletionHandler, IAgileObject)]
struct Activated(std::sync::mpsc::Sender<()>);

impl IActivateAudioInterfaceCompletionHandler_Impl for Activated_Impl {
    fn ActivateCompleted(
        &self,
        _operation: Ref<IActivateAudioInterfaceAsyncOperation>,
    ) -> windows::core::Result<()> {
        let _ = self.0.send(());
        Ok(())
    }
}

impl IAgileObject_Impl for Activated_Impl {}

struct Capture {
    client: IAudioClient,
    reader: IAudioCaptureClient,
    /// Signalled by Windows when audio is ready.
    ready: HANDLE,
}

fn open(pid: u32) -> Result<Capture, String> {
    // SAFETY: the activation blob points at `params`, which lives on this stack until the activation
    // completes (the PROPVARIANT is never dropped, see below). Every other call is a COM call on an
    // interface owned here, or on the event handle created here and handed to `Capture`.
    unsafe {
        let mut params = AUDIOCLIENT_ACTIVATION_PARAMS {
            ActivationType: AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK,
            ..Default::default()
        };
        params.Anonymous.ProcessLoopbackParams = AUDIOCLIENT_PROCESS_LOOPBACK_PARAMS {
            TargetProcessId: pid,
            ProcessLoopbackMode: PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE,
        };
        let mut property = PROPVARIANT::default();
        property.Anonymous = PROPVARIANT_0 {
            Anonymous: ManuallyDrop::new(PROPVARIANT_0_0 {
                vt: VT_BLOB,
                wReserved1: 0,
                wReserved2: 0,
                wReserved3: 0,
                Anonymous: PROPVARIANT_0_0_0 {
                    blob: BLOB {
                        cbSize: size_of::<AUDIOCLIENT_ACTIVATION_PARAMS>() as u32,
                        pBlobData: (&mut params as *mut AUDIOCLIENT_ACTIVATION_PARAMS).cast(),
                    },
                },
            }),
        };

        // The blob points at `params` on this stack: dropping a PROPVARIANT would free it, so never drop it.
        let property = ManuallyDrop::new(property);
        let (done, finished) = channel();
        let handler: IActivateAudioInterfaceCompletionHandler = Activated(done).into();
        let operation = ActivateAudioInterfaceAsync(
            VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,
            &IAudioClient::IID,
            Some(&*property),
            &handler,
        )
        .map_err(err)?;
        finished
            .recv_timeout(ACTIVATION_TIMEOUT)
            .map_err(|_| "the audio activation timed out".to_string())?;
        let mut result = HRESULT(0);
        let mut activated: Option<IUnknown> = None;
        operation
            .GetActivateResult(&mut result, &mut activated)
            .map_err(err)?;
        result.ok().map_err(err)?;
        let client: IAudioClient = activated.ok_or("no audio client")?.cast().map_err(err)?;

        let format = WAVEFORMATEX {
            wFormatTag: WAVE_FORMAT_PCM as u16,
            nChannels: CHANNELS,
            nSamplesPerSec: RATE,
            nAvgBytesPerSec: RATE * CHANNELS as u32 * 2,
            nBlockAlign: CHANNELS * 2,
            wBitsPerSample: 16,
            cbSize: 0,
        };
        // Event-driven, with the buffer left to Windows.
        client
            .Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                0,
                0,
                &format,
                None,
            )
            .map_err(err)?;
        let ready = CreateEventW(None, false, false, None).map_err(err)?;
        client.SetEventHandle(ready).map_err(err)?;
        let reader: IAudioCaptureClient = client.GetService().map_err(err)?;
        client.Start().map_err(err)?;
        Ok(Capture {
            client,
            reader,
            ready,
        })
    }
}

impl Capture {
    /// Appends everything captured since the last call to `mono` (as mono samples).
    fn drain(&self, mono: &mut Vec<f32>) -> Result<(), String> {
        // SAFETY: `reader` and `ready` belong to `self` and stay valid until `Drop`. `GetBuffer` hands
        // out `frames` frames of 16-bit stereo (the format `open` asked for), valid until the matching
        // `ReleaseBuffer`; the slice is copied into `mono` before that call.
        unsafe {
            // Wait for audio, but never long: silence still yields a pass every PASS.
            WaitForSingleObject(self.ready, PASS.as_millis() as u32);
            while self.reader.GetNextPacketSize().map_err(err)? > 0 {
                let (mut data, mut frames, mut flags) = (std::ptr::null_mut(), 0u32, 0u32);
                self.reader
                    .GetBuffer(&mut data, &mut frames, &mut flags, None, None)
                    .map_err(err)?;
                if flags & AUDCLNT_BUFFERFLAGS_SILENT.0 as u32 != 0 || data.is_null() {
                    mono.extend(std::iter::repeat_n(0.0, frames as usize));
                } else {
                    let samples = std::slice::from_raw_parts(
                        data.cast::<i16>(),
                        frames as usize * CHANNELS as usize,
                    );
                    mono_from_i16_stereo(samples, mono);
                }
                self.reader.ReleaseBuffer(frames).map_err(err)?;
            }
        }
        Ok(())
    }
}

impl Drop for Capture {
    fn drop(&mut self) {
        // SAFETY: `client` and `ready` are owned by `self` and used nowhere else after this point.
        unsafe {
            let _ = self.client.Stop();
            let _ = CloseHandle(self.ready);
        }
    }
}

/// Captures while Spotify has an audio session, feeding the scope on every pass; returns when the
/// audio process changed or went away, so the caller opens a new capture.
fn capture_once(pid: u32, scope: &Mutex<Scope>) -> Result<(), String> {
    let capture = open(pid)?;
    let mut checked = Instant::now();
    let mut mono = Vec::with_capacity(4096);
    loop {
        mono.clear();
        capture.drain(&mut mono)?;
        if mono.is_empty() {
            // Nothing arrived this pass (paused): a flat line, not the last shape frozen.
            mono.resize((RATE as u64 * PASS.as_millis() as u64 / 1000) as usize, 0.0);
        }
        lock(scope).push(&mono, Instant::now());
        if checked.elapsed() >= PID_CHECK {
            checked = Instant::now();
            if volume::spotify_pid()? != Some(pid) {
                return Ok(());
            }
        }
    }
}

/// Never returns: follows Spotify's audio for as long as the app runs, retrying quietly.
pub fn run(scope: Arc<Mutex<Scope>>) {
    // Capture runs on its own thread: COM in the multithreaded apartment, as the activation needs.
    // SAFETY: called once at the start of this thread, which owns its COM apartment.
    unsafe {
        let _ = CoInitializeEx(None, COINIT_MULTITHREADED);
    }
    loop {
        match volume::spotify_pid() {
            Ok(Some(pid)) => {
                let _ = capture_once(pid, &scope);
                std::thread::sleep(RETRY);
            }
            _ => std::thread::sleep(Duration::from_secs(1)),
        }
    }
}

#[cfg(test)]
mod tests;
