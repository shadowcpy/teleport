package gd.nexus.teleport

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "gd.nexus.teleport/app"

    override fun getCachedEngineId(): String {
        return TeleportApplication.ENGINE_ID
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        SharingSink.handleSharingIntent(this, intent, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "completeShare" -> {
                    finish()
                    result.success(null)
                }

                "openSharedFd" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("bad_args", "Missing uri", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriString)
                        val name = queryDisplayName(uri) ?: "shared_file"
                        val pfd = contentResolver.openFileDescriptor(uri, "r")
                            ?: throw IllegalStateException("Unable to open file descriptor")
                        val fd = pfd.detachFd()
                        result.success(mapOf("fd" to fd, "name" to name))
                    } catch (e: Exception) {
                        result.error("open_fd_failed", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        SharingSink.register(flutterEngine, this)
        SharingSink.handleSharingIntent(this, intent, true)
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex == -1) return null
            return cursor.getString(nameIndex)
        }
    }
}
