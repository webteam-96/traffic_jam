package com.kaizeninfotech.trafficjam

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Adds one platform method: saving a generated PDF into the device's public
 * Downloads folder.
 *
 * Flutter has no built-in way to do this. The app previously handed the PDF to
 * the system share sheet instead, relying on the user finding "Save to Files"
 * in it — which is a share, not a download, and didn't work reliably.
 *
 * Two code paths, because the platform changed under us:
 *
 *   API 29+  MediaStore. Scoped storage forbids writing to /Download directly,
 *            but an app may insert into the Downloads collection with no
 *            permission at all.
 *   API 24-28  The old world: a plain file write, which needs
 *            WRITE_EXTERNAL_STORAGE (declared in the manifest with
 *            maxSdkVersion="28" so newer devices never ask for it).
 */
class MainActivity : FlutterActivity() {
    private val channel = "trafficjam.life/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdfToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                if (bytes == null || fileName.isNullOrBlank()) {
                    result.error("BAD_ARGS", "bytes and fileName are required.", null)
                    return@setMethodCallHandler
                }

                try {
                    result.success(saveToDownloads(bytes, fileName))
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    /** Returns a human-readable location to show the user. */
    private fun saveToDownloads(bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                // Marks the row incomplete so nothing tries to open a
                // half-written file; cleared once the bytes are flushed.
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Couldn't create the file in Downloads.")

            resolver.openOutputStream(uri).use { stream ->
                stream ?: throw IllegalStateException("Couldn't open the file for writing.")
                stream.write(bytes)
            }

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Downloads"
        }

        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloads.exists()) downloads.mkdirs()
        val file = File(downloads, fileName)
        file.writeBytes(bytes)
        return "Downloads"
    }
}
