package dev.monicard.super_app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaMetadataRetriever
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** Android applicationId: dev.monicard.super_app */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.monicard.super_app/video"
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                io.execute {
                    try {
                        when (call.method) {
                            "probe" -> {
                                val value = probe(call.argument<String>("path")!!)
                                runOnUiThread { result.success(value) }
                            }
                            "frame" -> {
                                val jpeg =
                                    frameJpeg(
                                        path = call.argument<String>("path")!!,
                                        timeMs = call.argument<Int>("timeMs") ?: 0,
                                        sx = call.argument<Int>("sx"),
                                        sy = call.argument<Int>("sy"),
                                        sw = call.argument<Int>("sw"),
                                        sh = call.argument<Int>("sh"),
                                    )
                                runOnUiThread { result.success(jpeg) }
                            }
                            "frames" -> {
                                @Suppress("UNCHECKED_CAST")
                                val times = (call.argument<List<Int>>("timesMs") ?: emptyList())
                                val jpegs =
                                    framesJpeg(
                                        path = call.argument<String>("path")!!,
                                        timesMs = times,
                                        sx = call.argument<Int>("sx") ?: 0,
                                        sy = call.argument<Int>("sy") ?: 0,
                                        sw = call.argument<Int>("sw") ?: 240,
                                        sh = call.argument<Int>("sh") ?: 320,
                                    )
                                runOnUiThread { result.success(jpegs) }
                            }
                            else -> runOnUiThread { result.notImplemented() }
                        }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("video", error.message ?: "decode failed", null)
                        }
                    }
                }
            }
    }

    private fun open(path: String): MediaMetadataRetriever {
        val retriever = MediaMetadataRetriever()
        if (path.startsWith("content://")) {
            retriever.setDataSource(this, Uri.parse(path))
        } else {
            retriever.setDataSource(path)
        }
        return retriever
    }

    private fun probe(path: String): Map<String, Int> {
        val retriever = open(path)
        try {
            val durationMs =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toIntOrNull()
                    ?.coerceAtLeast(1)
                    ?: 1
            var width =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    ?.toIntOrNull()
                    ?: 0
            var height =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    ?.toIntOrNull()
                    ?: 0
            if (width <= 0 || height <= 0) {
                val frame = frameAt(retriever, 0)
                if (frame != null) {
                    width = frame.width
                    height = frame.height
                    frame.recycle()
                }
            }
            if (width <= 0 || height <= 0) {
                throw IllegalStateException("Could not read video size")
            }
            return mapOf(
                "durationMs" to durationMs,
                "width" to width,
                "height" to height,
            )
        } finally {
            retriever.release()
        }
    }

    private fun frameJpeg(
        path: String,
        timeMs: Int,
        sx: Int?,
        sy: Int?,
        sw: Int?,
        sh: Int?,
    ): ByteArray {
        val retriever = open(path)
        try {
            val bitmap = frameAt(retriever, timeMs) ?: throw IllegalStateException("No frame")
            try {
                val out =
                    if (sx != null && sy != null && sw != null && sh != null) {
                        cropToCard(bitmap, sx, sy, sw, sh)
                    } else {
                        bitmap
                    }
                try {
                    return toJpeg(out)
                } finally {
                    if (out !== bitmap) out.recycle()
                }
            } finally {
                bitmap.recycle()
            }
        } finally {
            retriever.release()
        }
    }

    private fun framesJpeg(
        path: String,
        timesMs: List<Int>,
        sx: Int,
        sy: Int,
        sw: Int,
        sh: Int,
    ): List<ByteArray> {
        val retriever = open(path)
        try {
            val out = ArrayList<ByteArray>(timesMs.size)
            for (time in timesMs) {
                val bitmap = frameAt(retriever, time) ?: continue
                try {
                    val card = cropToCard(bitmap, sx, sy, sw, sh)
                    try {
                        out.add(toJpeg(card))
                    } finally {
                        card.recycle()
                    }
                } finally {
                    bitmap.recycle()
                }
            }
            if (out.isEmpty()) throw IllegalStateException("No frames")
            return out
        } finally {
            retriever.release()
        }
    }

    private fun frameAt(retriever: MediaMetadataRetriever, timeMs: Int): Bitmap? {
        val micros = timeMs.toLong().coerceAtLeast(0) * 1000L
        return retriever.getFrameAtTime(micros, MediaMetadataRetriever.OPTION_CLOSEST)
            ?: retriever.getFrameAtTime(micros, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            ?: retriever.getFrameAtTime(micros, MediaMetadataRetriever.OPTION_PREVIOUS_SYNC)
    }

    private fun cropToCard(src: Bitmap, sx: Int, sy: Int, sw: Int, sh: Int): Bitmap {
        val left = sx.coerceIn(0, src.width - 1)
        val top = sy.coerceIn(0, src.height - 1)
        val width = sw.coerceAtLeast(1).coerceAtMost(src.width - left)
        val height = sh.coerceAtLeast(1).coerceAtMost(src.height - top)
        val out = Bitmap.createBitmap(240, 320, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(
            src,
            Rect(left, top, left + width, top + height),
            Rect(0, 0, 240, 320),
            paint,
        )
        return out
    }

    private fun toJpeg(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 82, stream)
        return stream.toByteArray()
    }
}
