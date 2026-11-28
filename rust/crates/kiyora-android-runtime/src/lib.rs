//! JNI host for the existing backend. Kotlin owns OS services, Rust owns audio.
//! The application (never an Activity) installs its JVM/context exactly once.
use jni::{
    JNIEnv, JavaVM,
    objects::{GlobalRef, JByteArray, JObject, JString, JValue},
    sys::{JNI_FALSE, JNI_TRUE, jboolean, jlong},
};
use std::{
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, Instant},
};
use uuid::Uuid;
use vault_core::{ApiError, Backend, ErrorCode};
use vault_media::{
    PlatformPlaybackSession, PlaybackControls, PlaybackError, PlaybackMetadata, PlaybackPlatform,
    PlaybackState,
};
use vault_security::{SecretStore, SecurityError};
use zeroize::Zeroizing;

struct Native {
    vm: JavaVM,
    bridge: GlobalRef,
    // Strong reference keeps ndk-context's pointer valid for the process lifetime.
    _application: GlobalRef,
}
static NATIVE: OnceLock<Native> = OnceLock::new();
static INSTALL: Mutex<()> = Mutex::new(());
static CONTROLS: Mutex<Option<(Uuid, PlaybackControls)>> = Mutex::new(None);

fn unavailable() -> ApiError {
    ApiError::new(ErrorCode::NativeUnavailable)
}

/// Called by Application.onCreate before Flutter starts. JNI arguments are
/// supplied by the VM; neither reference is retained without NewGlobalRef.
pub fn install(env: JNIEnv, bridge: JObject, application: JObject) -> jboolean {
    let result =
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| -> Result<(), ApiError> {
            let _guard = INSTALL.lock().map_err(|_| unavailable())?;
            if NATIVE.get().is_some() {
                return Ok(());
            }
            let native = Native {
                vm: env.get_java_vm().map_err(|_| unavailable())?,
                bridge: env.new_global_ref(bridge).map_err(|_| unavailable())?,
                _application: env.new_global_ref(application).map_err(|_| unavailable())?,
            };
            // SAFETY: this process calls installation on Application.onCreate before
            // any audio worker exists. INSTALL serializes repeat calls; NATIVE owns
            // the VM and a global Application reference until process termination.
            unsafe {
                ndk_context::initialize_android_context(
                    native.vm.get_java_vm_pointer().cast(),
                    native._application.as_obj().as_raw().cast(),
                );
            }
            NATIVE.set(native).map_err(|_| unavailable())?;
            Ok(())
        }));
    if matches!(result, Ok(Ok(()))) {
        JNI_TRUE
    } else {
        let _ = env.exception_clear();
        JNI_FALSE
    }
}

fn call<T>(
    f: impl FnOnce(&mut JNIEnv<'_>, &JObject<'_>) -> jni::errors::Result<T>,
) -> Result<T, ApiError> {
    let native = NATIVE.get().ok_or_else(unavailable)?;
    let mut env = native
        .vm
        .attach_current_thread()
        .map_err(|_| unavailable())?;
    let result = env.with_local_frame(32, |env| f(env, native.bridge.as_obj()));
    if result.is_err() {
        let _ = env.exception_clear();
    }
    result.map_err(|_| unavailable())
}

fn string_call(method: &str, args: &[String]) -> Result<String, ApiError> {
    call(|env, bridge| {
        let strings = args
            .iter()
            .map(|s| env.new_string(s).map(JObject::from))
            .collect::<jni::errors::Result<Vec<_>>>()?;
        let values = strings.iter().map(JValue::Object).collect::<Vec<_>>();
        let signature = format!(
            "({})Ljava/lang/String;",
            "Ljava/lang/String;".repeat(values.len())
        );
        let value = env.call_method(bridge, method, signature, &values)?.l()?;
        let result = env.get_string(&JString::from(value))?.into();
        Ok(result)
    })
}

struct Secrets;
impl SecretStore for Secrets {
    fn get(&self, key: &str) -> Result<Option<Zeroizing<Vec<u8>>>, SecurityError> {
        call(|env, bridge| {
            let key = JObject::from(env.new_string(key)?);
            let value = env
                .call_method(
                    bridge,
                    "getSecret",
                    "(Ljava/lang/String;)[B",
                    &[JValue::Object(&key)],
                )?
                .l()?;
            if value.is_null() {
                return Ok(None);
            }
            let array = JByteArray::from(value);
            let bytes = Zeroizing::new(env.convert_byte_array(&array)?);
            env.set_byte_array_region(&array, 0, &vec![0; bytes.len()])?;
            Ok(Some(bytes))
        })
        .map_err(|_| SecurityError::SecureStorageUnavailable)?
        .map(|bytes| {
            if bytes.len() == 32 {
                Ok(bytes)
            } else {
                Err(SecurityError::SecureStorageUnavailable)
            }
        })
        .transpose()
    }
    fn set(&self, key: &str, value: &[u8]) -> Result<(), SecurityError> {
        if value.len() != 32 {
            return Err(SecurityError::SecureStorageUnavailable);
        }
        call(|env, bridge| {
            let key = JObject::from(env.new_string(key)?);
            let bytes = env.byte_array_from_slice(value)?;
            let result = env.call_method(
                bridge,
                "setSecret",
                "(Ljava/lang/String;[B)V",
                &[JValue::Object(&key), JValue::Object(bytes.as_ref())],
            );
            if result.is_err() {
                let _ = env.exception_clear();
            }
            env.set_byte_array_region(&bytes, 0, &[0; 32])?;
            result.map(|_| ())
        })
        .map_err(|_| SecurityError::SecureStorageUnavailable)
    }
}

pub fn backend() -> Result<Backend, ApiError> {
    let profiles = PathBuf::from(string_call("profilesPath", &[])?);
    let tdjson = PathBuf::from(string_call("tdjsonPath", &[])?);
    Ok(Backend::with_secrets(
        vault_security::ProfileStore::at(profiles)?,
        tdjson,
        Arc::new(Secrets),
    )
    .with_playback_platform(Arc::new(Media))
    .with_import_resolver(Arc::new(Documents)))
}

struct Media;
struct MediaSession {
    owner: Uuid,
    last_update: Option<(Instant, u8)>,
    // The shared engine calls stop once immediately after publishing Ended.
    // Retain Android's foreground service across this queue handoff; a later
    // explicit stop (including an exhausted queue) still tears it down.
    finishing_track: bool,
}
impl MediaSession {
    fn send(&self, action: &str, payload: String) -> Result<(), PlaybackError> {
        call(|env, bridge| {
            let owner = JObject::from(env.new_string(self.owner.to_string())?);
            let action = JObject::from(env.new_string(action)?);
            let payload = JObject::from(env.new_string(payload)?);
            env.call_method(
                bridge,
                "mediaCall",
                "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z",
                &[
                    JValue::Object(&owner),
                    JValue::Object(&action),
                    JValue::Object(&payload),
                ],
            )?
            .z()
        })
        .map_err(|_| PlaybackError::DeviceUnavailable)?
        .then_some(())
        .ok_or(PlaybackError::DeviceUnavailable)
    }
}
impl PlaybackPlatform for Media {
    fn connect(
        &self,
        controls: PlaybackControls,
    ) -> Result<Box<dyn PlatformPlaybackSession>, PlaybackError> {
        if NATIVE.get().is_none() {
            return Err(PlaybackError::DeviceUnavailable);
        }
        let session = MediaSession {
            owner: Uuid::new_v4(),
            last_update: None,
            finishing_track: false,
        };
        {
            let mut slot = CONTROLS
                .lock()
                .map_err(|_| PlaybackError::DeviceUnavailable)?;
            if slot.is_some() {
                return Err(PlaybackError::DeviceUnavailable);
            }
            *slot = Some((session.owner, controls));
        }
        session.send("open", String::new())?;
        Ok(Box::new(session))
    }
}
impl PlatformPlaybackSession for MediaSession {
    fn prepare(&mut self, metadata: &PlaybackMetadata) -> Result<(), PlaybackError> {
        self.finishing_track = false;
        self.last_update = None;
        self.send(
            "prepare",
            serde_json::to_string(metadata).map_err(|_| PlaybackError::DeviceUnavailable)?,
        )
    }
    fn pause(&mut self) -> Result<(), PlaybackError> {
        self.last_update = None;
        self.send("pause", String::new())
    }
    fn resume(&mut self) -> Result<(), PlaybackError> {
        self.last_update = None;
        self.send("resume", String::new())
    }
    fn update(&mut self, state: &PlaybackState) -> Result<(), PlaybackError> {
        if matches!(state, PlaybackState::Ended { .. }) {
            self.last_update = None;
            self.send("ended", String::new())?;
            self.finishing_track = true;
            return Ok(());
        }
        let kind = match state {
            PlaybackState::Idle | PlaybackState::Ended { .. } => 0,
            PlaybackState::Buffering { .. } => 1,
            PlaybackState::Playing { .. } => 2,
            PlaybackState::Paused { .. } => 3,
            PlaybackState::Failed { .. } => 4,
        };
        if self
            .last_update
            .as_ref()
            .is_some_and(|(at, last)| *last == kind && at.elapsed() < Duration::from_secs(1))
        {
            return Ok(());
        }
        self.send(
            "update",
            serde_json::to_string(state).map_err(|_| PlaybackError::DeviceUnavailable)?,
        )?;
        self.last_update = Some((Instant::now(), kind));
        Ok(())
    }
    fn stop(&mut self) {
        self.last_update = None;
        if std::mem::take(&mut self.finishing_track) {
            return;
        }
        let _ = self.send("stop", String::new());
    }
    fn artwork(&mut self, track_id: Uuid, bytes: &[u8]) -> Result<(), PlaybackError> {
        if bytes.len() > 256 * 1024 {
            return Err(PlaybackError::DeviceUnavailable);
        }
        call(|env, bridge| {
            let owner = JObject::from(env.new_string(self.owner.to_string())?);
            let track = JObject::from(env.new_string(track_id.to_string())?);
            let bytes = env.byte_array_from_slice(bytes)?;
            env.call_method(
                bridge,
                "artwork",
                "(Ljava/lang/String;Ljava/lang/String;[B)Z",
                &[
                    JValue::Object(&owner),
                    JValue::Object(&track),
                    JValue::Object(bytes.as_ref()),
                ],
            )?
            .z()
        })
        .map_err(|_| PlaybackError::DeviceUnavailable)?
        .then_some(())
        .ok_or(PlaybackError::DeviceUnavailable)
    }
}
impl Drop for MediaSession {
    fn drop(&mut self) {
        // Do not let a replacement connect until Kotlin has closed this owner.
        let _ = self.send("close", String::new());
        if let Ok(mut slot) = CONTROLS.lock() {
            if slot.as_ref().is_some_and(|(owner, _)| *owner == self.owner) {
                *slot = None;
            }
        }
    }
}

pub fn control(
    mut env: JNIEnv,
    _bridge: JObject,
    owner: JString,
    action: JString,
    position: jlong,
) -> jboolean {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| -> Option<()> {
        let owner: String = env.get_string(&owner).ok()?.into();
        let owner = Uuid::parse_str(&owner).ok()?;
        let action: String = env.get_string(&action).ok()?.into();
        let controls = {
            let slot = CONTROLS.lock().ok()?;
            let (current, controls) = slot.as_ref()?;
            if *current != owner {
                return None;
            }
            controls.clone()
        };
        match action.as_str() {
            "pause" => controls.pause(),
            "resume" => controls.resume(),
            "stop" => controls.stop(),
            "next" => controls.next(),
            "previous" => controls.previous(),
            "seek" => controls.seek(u64::try_from(position).ok()?),
            _ => return None,
        }
        .ok()
    }));
    if matches!(result, Ok(Some(()))) {
        JNI_TRUE
    } else {
        let _ = env.exception_clear();
        JNI_FALSE
    }
}

struct Documents;
impl vault_core::ImportResolver for Documents {
    fn resolve(
        &self,
        uri: String,
        op_id: Uuid,
        cancel: tokio_util::sync::CancellationToken,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<PathBuf, ApiError>> + Send + '_>>
    {
        Box::pin(async move {
            if cancel.is_cancelled() {
                return Err(ApiError::new(ErrorCode::Cancelled));
            }
            let id = op_id.to_string();
            let begin_id = id.clone();
            tokio::task::spawn_blocking(move || string_call("beginDocument", &[begin_id]))
                .await
                .map_err(|_| unavailable())??;
            let request_id = id.clone();
            let mut task = tokio::task::spawn_blocking(move || {
                string_call("stageDocument", &[request_id, uri]).map(PathBuf::from)
            });
            tokio::select! {
                result = &mut task => result.map_err(|_| unavailable())?,
                _ = cancel.cancelled() => {
                    let _ = tokio::task::spawn_blocking(move || string_call("cancelDocument", &[id])).await;
                    let _ = task.await;
                    Err(ApiError::new(ErrorCode::Cancelled))
                }
            }
        })
    }
    fn release(
        &self,
        op_id: Uuid,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), ApiError>> + Send + '_>>
    {
        Box::pin(async move {
            tokio::task::spawn_blocking(move || {
                string_call("releaseDocument", &[op_id.to_string()]).map(|_| ())
            })
            .await
            .map_err(|_| unavailable())?
        })
    }
}
