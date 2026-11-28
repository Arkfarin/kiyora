package io.github.arkfarin.kiyora

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var hostChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        hostChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.arkfarin.kiyora/host").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "preferencesDirectory" -> result.success(applicationContext.filesDir.absolutePath)
                    "openProjectPage" -> {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/Arkfarin/kiyora")))
                            result.success(null)
                        } catch (_: ActivityNotFoundException) {
                            result.error("NO_BROWSER", "No browser available", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        hostChannel?.setMethodCallHandler(null)
        hostChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
