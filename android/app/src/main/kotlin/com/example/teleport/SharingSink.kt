package gd.nexus.teleport

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object SharingSink {
    private const val SHARE_METHOD_CHANNEL = "sharing_sink/methods"
    private const val SHARE_EVENT_CHANNEL = "sharing_sink/events"
    private var sharingEventSink: EventChannel.EventSink? = null
    private var initialSharing: List<Map<String, Any?>>? = null
    private var latestSharing: List<Map<String, Any?>>? = null

    fun register(flutterEngine: FlutterEngine, activity: Activity) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharing" -> {
                    result.success(initialSharing)
                    initialSharing = null
                }
                "reset" -> {
                    initialSharing = null
                    latestSharing = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sharingEventSink = events
                latestSharing?.let { events?.success(it) }
            }

            override fun onCancel(arguments: Any?) {
                sharingEventSink = null
            }
        })
    }

    fun handleSharingIntent(activity: Activity, intent: Intent, initial: Boolean) {
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        val items = mutableListOf<Map<String, Any?>>()
        val type = intent.type
        if (type?.startsWith("text") == true) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (text != null) {
                items.add(
                    mapOf(
                        "value" to text,
                        "type" to SharingItemType.TEXT.ordinal,
                        "mimeType" to type
                    )
                )
            }
        } else {
            items.addAll(collectUriItems(activity, intent))
        }

        if (items.isEmpty()) return
        if (initial) initialSharing = items
        latestSharing = items
        sharingEventSink?.success(items)
    }

    private fun collectUriItems(
        activity: Activity,
        intent: Intent,
    ): List<Map<String, Any?>> {
        val uris = LinkedHashSet<Uri>()
        if (intent.action == Intent.ACTION_SEND) {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        } else if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
        }
        val clipData: ClipData? = intent.clipData
        if (clipData != null) {
            for (i in 0 until clipData.itemCount) {
                clipData.getItemAt(i)?.uri?.let { uris.add(it) }
            }
        }
        return uris.map { uri ->
            val mimeType = activity.contentResolver.getType(uri) ?: intent.type
            mapOf(
                "value" to uri.toString(),
                "type" to mapMimeToType(mimeType).ordinal,
                "mimeType" to mimeType
            )
        }
    }

    private fun mapMimeToType(mimeType: String?): SharingItemType {
        return when {
            mimeType?.startsWith("image") == true -> SharingItemType.IMAGE
            mimeType?.startsWith("video") == true -> SharingItemType.VIDEO
            mimeType?.startsWith("text") == true -> SharingItemType.TEXT
            else -> SharingItemType.FILE
        }
    }

    private enum class SharingItemType {
        TEXT,
        URL,
        IMAGE,
        VIDEO,
        FILE,
        WEB_SEARCH,
        OTHER,
    }
}
