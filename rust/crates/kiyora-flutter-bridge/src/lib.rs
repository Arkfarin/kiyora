/// Direct native adapter over the shared backend and playback engine.
pub mod api;
mod credentials;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

#[cfg(any(target_os = "linux", target_os = "windows"))]
mod desktop;

#[cfg(target_os = "android")]
mod android;
