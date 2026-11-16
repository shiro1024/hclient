package shiro.hclient

import androidx.activity.BackEventCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal data class EdgeDrawerTarget(val id: Long, val side: String)

/** The visible Flutter route supplies its available drawers; the OS owns the swipe. */
class EdgeDrawerHost(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "shiro.hclient.edge_drawer")
    private var id: Long? = null
    private var left = false
    private var right = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "update") {
                val arguments = call.arguments as Map<*, *>
                id = (arguments["id"] as? Number)?.toLong()
                left = arguments["left"] == true
                right = arguments["right"] == true
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    internal fun target(backEvent: BackEventCompat, middleY: Float): EdgeDrawerTarget? {
        val owner = id ?: return null
        val side = when {
            backEvent.swipeEdge == BackEventCompat.EDGE_LEFT && left -> "left"
            backEvent.swipeEdge == BackEventCompat.EDGE_RIGHT && right && backEvent.touchY < middleY -> "right"
            else -> return null
        }
        return EdgeDrawerTarget(owner, side)
    }

    internal fun open(target: EdgeDrawerTarget) {
        channel.invokeMethod("open", mapOf("id" to target.id, "side" to target.side))
    }
}
