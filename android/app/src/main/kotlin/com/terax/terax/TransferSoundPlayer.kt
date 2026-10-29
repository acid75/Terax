package com.terax.terax

import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Small local clips only; loading is asynchronous and never holds up a transfer. */
class TransferSoundPlayer {
    private val ui = Handler(Looper.getMainLooper())
    private val pool = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
    private val loaded = mutableMapOf<String, Int>()
    private val pending = mutableMapOf<Int, Pair<String, MethodChannel.Result>>()
    private val streams = mutableListOf<Int>()
    private var closed = false
    init {
        pool.setOnLoadCompleteListener { _, id, status -> ui.post {
            val item = pending.remove(id) ?: return@post
            if (!closed && status == 0) {
                loaded[item.first] = id
                item.second.success(playLoaded(id))
            } else { pool.unload(id); item.second.success(false) }
        } }
    }
    private fun playLoaded(id: Int): Boolean {
        streams.forEach { pool.stop(it) }; streams.clear()
        val stream = pool.play(id, 1f, 1f, 1, 0, 1f)
        if (stream != 0) streams.add(stream)
        return stream != 0
    }
    fun play(path: String?, result: MethodChannel.Result) {
        if (closed || path.isNullOrBlank() || path.length > 32767 || !File(path).isFile || File(path).length() > 262144) {
            result.success(false); return
        }
        loaded[path]?.let { result.success(playLoaded(it)); return }
        if (pending.isNotEmpty()) { result.success(false); return }
        if (loaded.size >= 2) { loaded.values.forEach { pool.unload(it) }; loaded.clear() }
        try {
            val id = pool.load(path, 1)
            if (id == 0) result.success(false)
            else {
                pending[id] = Pair(path, result)
                ui.postDelayed({ pending.remove(id)?.let { pool.unload(id); it.second.success(false) } }, 3000)
            }
        } catch (_: Exception) { result.success(false) }
    }
    fun stop() {
        streams.forEach { pool.stop(it) }; streams.clear()
        pending.toMap().forEach { (id, item) -> pool.unload(id); item.second.success(false) }
        pending.clear()
    }
    fun dispose() {
        if (closed) return
        closed = true; stop(); loaded.clear(); pool.release(); ui.removeCallbacksAndMessages(null)
    }
}
