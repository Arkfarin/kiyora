use std::sync::atomic::{AtomicBool, Ordering};
use vault_core::{ApiError, ErrorCode};

static RAISE: AtomicBool = AtomicBool::new(false);
pub(crate) struct Host {
    window: Option<usize>,
}
impl Host {
    pub(crate) fn new(window: Option<u64>) -> Result<Self, ApiError> {
        let window = window
            .map(usize::try_from)
            .transpose()
            .map_err(|_| ApiError::new(ErrorCode::InvalidInput))?;
        #[cfg(target_os = "windows")]
        if window.is_none_or(|v| v == 0) {
            return Err(ApiError::new(ErrorCode::NativeUnavailable));
        }
        RAISE.store(false, Ordering::Release);
        Ok(Self { window })
    }
}
impl kiyora_desktop_media::DesktopHost for Host {
    fn window_handle(&self) -> Option<usize> {
        self.window
    }
    fn raise(&self) {
        RAISE.store(true, Ordering::Release);
    }
}
pub(crate) fn take_raise() -> bool {
    RAISE.swap(false, Ordering::AcqRel)
}
