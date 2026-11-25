//! Export JNI entrypoints from the same cdylib loaded by Flutter and Kotlin.
use jni::{
    JNIEnv,
    objects::{JObject, JString},
    sys::{jboolean, jlong},
};

#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_arkfarin_kiyora_nativebridge_FlutterNativeBridge_nativeInstall(
    env: JNIEnv,
    bridge: JObject,
    application: JObject,
) -> jboolean {
    kiyora_android_runtime::install(env, bridge, application)
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_arkfarin_kiyora_nativebridge_FlutterNativeBridge_nativeControl(
    env: JNIEnv,
    bridge: JObject,
    owner: JString,
    action: JString,
    position: jlong,
) -> jboolean {
    kiyora_android_runtime::control(env, bridge, owner, action, position)
}
