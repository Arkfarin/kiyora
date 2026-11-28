package io.github.arkfarin.kiyora.nativebridge

import android.app.Application
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

/** Native calls originate on Rust workers, never on the UI or audio callback.
 * The existing Kotlin service retains audio focus, owner fencing and wake locks.
 * No Flutter engine, Dart isolate or Activity is required for media controls. */
object FlutterNativeBridge {
    private lateinit var application: Application
    private val main = Handler(Looper.getMainLooper())
    private val secrets by lazy { KeystoreSecrets(application) }
    private val documents by lazy { DocumentImports(application) }
    private val copies = ConcurrentHashMap<String, DocumentCopy>()
    private var installed = false

    @Synchronized
    fun install(context: Application) {
        if (installed) return
        System.loadLibrary("kiyora_flutter_bridge")
        application = context
        check(nativeInstall(context)) { "Native runtime initialization failed" }
        installed = true
    }
    private external fun nativeInstall(context: Application): Boolean
    private external fun nativeControl(owner: String, action: String, position: Long): Boolean

    fun profilesPath(): String {
        val root = File(application.noBackupFilesDir.canonicalFile, "kiyora")
        check(root.isDirectory || root.mkdirs())
        check(root.canonicalFile == root.absoluteFile)
        return root.path
    }
    fun tdjsonPath() = File(application.applicationInfo.nativeLibraryDir, "libtdjson.so").path
    fun getSecret(key: String): ByteArray? = secrets.get(key)
    fun setSecret(key: String, value: ByteArray) {
        try { secrets.set(key, value) } finally { value.fill(0) }
    }

    private fun onMain(owner: String, closeOnTimeout: Boolean = false, stopOnTimeout: Boolean = true, action: (done: (Boolean) -> Unit) -> Unit): Boolean {
        check(Looper.myLooper() != Looper.getMainLooper())
        val latch = CountDownLatch(1)
        val settled = AtomicBoolean(false)
        val result = AtomicBoolean(false)
        val done: (Boolean) -> Unit = { success ->
            if (settled.compareAndSet(false, true)) { result.set(success); latch.countDown() }
        }
        main.post {
            if (!settled.get()) {
                try { action(done) }
                catch (_: Exception) { done(false) }
                catch (_: LinkageError) { done(false) }
            }
        }
        if (!latch.await(10, TimeUnit.SECONDS)) {
            settled.set(true)
            if (stopOnTimeout) main.post {
                try {
                    if (closeOnTimeout) NativePlayback.close(owner) else NativePlayback.stop(owner)
                } catch (_: Exception) {}
            }
            return false
        }
        return result.get()
    }
    fun mediaCall(owner: String, action: String, payload: String): Boolean = onMain(owner, action == "open" || action == "close") { done ->
        when (action) {
            "open" -> {
                NativePlayback.open(application, owner) { control, position ->
                    check(nativeControl(owner, control, position ?: 0)) { "Playback controller is unavailable" }
                }
                done(true)
            }
            "prepare" -> NativePlayback.prepare(owner, JSONObject(payload), done)
            "resume" -> NativePlayback.resume(owner, done)
            "pause" -> { NativePlayback.pause(owner); done(true) }
            "update" -> { NativePlayback.update(owner, JSONObject(payload)); done(true) }
            "ended" -> { NativePlayback.ended(owner); done(true) }
            "stop" -> { NativePlayback.stop(owner); done(true) }
            "close" -> { NativePlayback.close(owner); done(true) }
            else -> done(false)
        }
    }
    fun artwork(owner: String, track: String, bytes: ByteArray): Boolean = onMain(owner, stopOnTimeout = false) { done ->
        require(bytes.size <= 256 * 1024)
        NativePlayback.requireOwner(owner).service?.setArtwork(track, bytes)
        done(true)
    }

    fun beginDocument(id: String): String {
        require(UUID.fromString(id).toString() == id)
        check(copies.putIfAbsent(id, DocumentCopy()) == null)
        return ""
    }
    fun stageDocument(id: String, uri: String): String {
        val control = checkNotNull(copies[id])
        try { return documents.stage(id, uri, control).path }
        finally { copies.remove(id, control) }
    }
    fun cancelDocument(id: String): String { copies[id]?.cancel(); return "" }
    fun releaseDocument(id: String): String { documents.release(id); return "" }
}
