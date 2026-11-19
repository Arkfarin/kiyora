//! Tauri host adapter for the shared MPRIS/SMTC implementation.
use std::sync::Arc;
use tauri::{AppHandle, Manager, Runtime};
use vault_media::{PlatformPlaybackSession, PlaybackControls, PlaybackError, PlaybackPlatform};

struct Host<R: Runtime>(AppHandle<R>);
impl<R: Runtime> kiyora_desktop_media::DesktopHost for Host<R> {
    fn window_handle(&self) -> Option<usize> {
        #[cfg(target_os = "windows")]
        {
            self.0
                .get_webview_window("main")?
                .hwnd()
                .ok()
                .map(|h| h.0 as usize)
        }
        #[cfg(not(target_os = "windows"))]
        {
            None
        }
    }
    fn raise(&self) {
        if let Some(window) = self.0.get_webview_window("main") {
            let _ = window.show();
            let _ = window.unminimize();
            let _ = window.set_focus();
        }
    }
}
pub struct DesktopMedia(kiyora_desktop_media::DesktopMedia);
impl DesktopMedia {
    pub fn new<R: Runtime>(app: AppHandle<R>) -> Self {
        Self(kiyora_desktop_media::DesktopMedia::new(Arc::new(Host(app))))
    }
}
impl PlaybackPlatform for DesktopMedia {
    fn connect(
        &self,
        controls: PlaybackControls,
    ) -> Result<Box<dyn PlatformPlaybackSession>, PlaybackError> {
        self.0.connect(controls)
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};
    use uuid::Uuid;
    use vault_media::{PlaybackMetadata, PlaybackState};
    #[cfg(target_os = "linux")]
    #[test]
    #[ignore = "requires an isolated D-Bus session and a working audio output; plays digital silence"]
    #[allow(clippy::unwrap_used)]
    fn linux_mpris_controls_the_rust_engine() {
        use vault_media::{CacheManager, PlaybackEngine, PlaybackInput};
        fn wait(mut condition: impl FnMut() -> bool) {
            let deadline = Instant::now() + Duration::from_secs(5);
            while !condition() {
                assert!(Instant::now() < deadline, "native state did not converge");
                std::thread::sleep(Duration::from_millis(20));
            }
        }
        fn dbus(method: &str, args: &[&str]) -> String {
            let output = std::process::Command::new("gdbus")
                .args([
                    "call",
                    "--session",
                    "--timeout",
                    "3",
                    "--dest",
                    "org.mpris.MediaPlayer2.kiyora",
                    "--object-path",
                    "/org/mpris/MediaPlayer2",
                    "--method",
                    method,
                ])
                .args(args)
                .output()
                .unwrap();
            assert!(
                output.status.success(),
                "{}",
                String::from_utf8_lossy(&output.stderr)
            );
            String::from_utf8(output.stdout).unwrap()
        }
        let temp = tempfile::tempdir().unwrap();
        let frames: u32 = 8000 * 120;
        let mut wav = Vec::new();
        wav.extend(b"RIFF");
        wav.extend((36 + frames * 2).to_le_bytes());
        wav.extend(b"WAVEfmt ");
        wav.extend(16u32.to_le_bytes());
        wav.extend(1u16.to_le_bytes());
        wav.extend(1u16.to_le_bytes());
        wav.extend(8000u32.to_le_bytes());
        wav.extend(16000u32.to_le_bytes());
        wav.extend(2u16.to_le_bytes());
        wav.extend(16u16.to_le_bytes());
        wav.extend(b"data");
        wav.extend((frames * 2).to_le_bytes());
        wav.resize(wav.len() + frames as usize * 2, 0);
        let path = temp.path().join("silence.wav");
        std::fs::write(&path, wav).unwrap();
        let source = vault_media::inspect(&path).unwrap();
        let cache = CacheManager::open(temp.path().join("cache"), 4_000_000).unwrap();
        let lease = cache
            .insert("native-test".into(), &path, &source.sha256, false)
            .unwrap();
        let app = tauri::test::mock_app();
        let mut engine =
            PlaybackEngine::open_with_platform(Arc::new(DesktopMedia::new(app.handle().clone())))
                .unwrap();
        let mut navigation = engine.take_navigation().unwrap();
        engine
            .play_input_with_metadata(
                PlaybackMetadata {
                    track_id: Uuid::new_v4(),
                    title: "KIYORA native test".into(),
                    performer: "Digital silence".into(),
                    duration_ms: 120_000,
                },
                PlaybackInput::Cached(lease),
            )
            .unwrap();
        wait(|| matches!(engine.state(), PlaybackState::Playing { .. }));
        let metadata = dbus(
            "org.freedesktop.DBus.Properties.Get",
            &["org.mpris.MediaPlayer2.Player", "Metadata"],
        );
        assert!(metadata.contains("KIYORA native test") && metadata.contains("Digital silence"));
        dbus("org.mpris.MediaPlayer2.Player.Pause", &[]);
        wait(|| matches!(engine.state(), PlaybackState::Paused { .. }));
        dbus(
            "org.mpris.MediaPlayer2.Player.SetPosition",
            &["/", "30000000"],
        );
        wait(
            || matches!(engine.state(), PlaybackState::Paused {position_ms, ..} if (29_000..=31_000).contains(&position_ms)),
        );
        dbus("org.mpris.MediaPlayer2.Player.Play", &[]);
        wait(|| matches!(engine.state(), PlaybackState::Playing { .. }));
        dbus("org.mpris.MediaPlayer2.Player.Next", &[]);
        wait(|| navigation.try_recv().is_ok_and(|forward| forward));
        dbus("org.mpris.MediaPlayer2.Player.Previous", &[]);
        wait(|| navigation.try_recv().is_ok_and(|forward| !forward));
        dbus("org.mpris.MediaPlayer2.Player.Stop", &[]);
        wait(|| matches!(engine.state(), PlaybackState::Idle));
    }
}
