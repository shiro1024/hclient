package shiro.hclient

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class HClientApplication : Application() {
    var existingEngine: FlutterEngine? = null
        private set
    lateinit var transferHost: TransferHost
        private set
    lateinit var edgeDrawerHost: EdgeDrawerHost
        private set
    var interceptVolumeEvent = false
        private set
    private var volumeChannel: MethodChannel? = null

    fun obtainEngine(): FlutterEngine {
        existingEngine?.let { return it }
        // Only the normal Activity creates/starts the runtime. A service never
        // calls obtainEngine and no Dart entrypoint is executed here.
        val engine = FlutterEngine(this, null, false)
        existingEngine = engine
        GeneratedPluginRegistrant.registerWith(engine)
        volumeChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "shiro.hclient.volume.event.intercept").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "set") {
                    (call.arguments as? Boolean)?.let { value -> interceptVolumeEvent = value }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
        transferHost = TransferHost(this, engine.dartExecutor.binaryMessenger)
        edgeDrawerHost = EdgeDrawerHost(engine.dartExecutor.binaryMessenger)
        return engine
    }

    fun volumeEvent(up: Boolean) {
        volumeChannel?.invokeMethod("event", if (up) 1 else -1)
    }
}
