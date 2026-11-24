//! Application credentials stay on the native side of the bridge. Embedded
//! desktop credentials can be extracted from binaries; this is not encryption.
use crate::api::BridgeError;
use zeroize::Zeroizing;

pub(crate) fn telegram() -> Result<(i32, Zeroizing<String>), BridgeError> {
    let packed = include_bytes!(concat!(env!("OUT_DIR"), "/telegram.bin"));
    let unavailable = || BridgeError {
        code: "AppConfigurationUnavailable".into(),
        message:
            "В этой сборке недоступен вход в Telegram. Установите настроенную сборку приложения."
                .into(),
        retryable: false,
        retry_after_seconds: None,
    };
    let id = packed
        .get(..4)
        .and_then(|v| v.try_into().ok())
        .ok_or_else(unavailable)?;
    let hash = packed
        .get(4..36)
        .and_then(|v| std::str::from_utf8(v).ok())
        .ok_or_else(unavailable)?;
    Ok((i32::from_le_bytes(id), Zeroizing::new(hash.to_owned())))
}
