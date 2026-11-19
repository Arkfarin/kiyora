package io.github.arkfarin.kiyora

import android.app.Application
import io.github.arkfarin.kiyora.nativebridge.FlutterNativeBridge

class KiyoraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // This reference and Rust session outlive Activity recreation.
        FlutterNativeBridge.install(this)
    }
}
