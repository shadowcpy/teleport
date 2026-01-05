package gd.nexus.teleport

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.teleport/app"

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "minimize" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "copySharedFile" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("bad_args", "Missing uri", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val path = copySharedFileToCache(Uri.parse(uriString))
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("copy_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun copySharedFileToCache(uri: Uri): String {
        val displayName = queryDisplayName(uri) ?: "shared_${System.currentTimeMillis()}"
        val outFile = File(cacheDir, uniqueName(displayName))
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("Unable to open input stream")
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        }
        return outFile.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex == -1) return null
            return cursor.getString(nameIndex)
        }
    }

    private fun uniqueName(base: String): String {
        val file = File(cacheDir, base)
        if (!file.exists()) return base
        val dot = base.lastIndexOf('.')
        val stem = if (dot > 0) base.substring(0, dot) else base
        val ext = if (dot > 0) base.substring(dot) else ""
        return "${stem}_${System.currentTimeMillis()}$ext"
    }
}
