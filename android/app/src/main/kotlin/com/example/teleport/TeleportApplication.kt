package gd.nexus.teleport

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class TeleportApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        if (FlutterEngineCache.getInstance().get(ENGINE_ID) != null) {
            return
        }

        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "main_engine"
    }
}
