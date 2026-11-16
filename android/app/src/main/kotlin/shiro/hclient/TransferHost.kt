package shiro.hclient

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** A view of Dart's current transfer facts, with no task persistence or execution. */
internal data class TransferSnapshot(
    val active: Boolean,
    val title: String,
    val text: String,
    val lines: List<String>,
    val progress: Long?,
    val total: Long?,
    val target: String,
) {
    companion object {
        fun from(arguments: Any?): TransferSnapshot {
            val values = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            return TransferSnapshot(
                values["active"] == true,
                values["title"] as? String ?: "",
                values["text"] as? String ?: "",
                (values["lines"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                (values["progress"] as? Number)?.toLong(),
                (values["total"] as? Number)?.toLong(),
                transferTarget(values["target"] as? String),
            )
        }
    }
}

internal fun transferTarget(target: String?) = when (target) {
    "archive", "cloud" -> target
    else -> "download"
}

class TransferHost(private val app: HClientApplication, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "shiro.hclient.transfer")
    private var activity: MainActivity? = null
    private var resumed = false
    private var blockedUntilResume = false
    private var starting = false
    private var service: TransferService? = null
    private val pendingStarts = mutableListOf<MethodChannel.Result>()
    private var navigationReady = false
    private var pendingTarget: String? = null
    internal var snapshot = TransferSnapshot.from(null)
        private set

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> update(TransferSnapshot.from(call.arguments), result)
                "consumeNotificationTarget" -> {
                    navigationReady = true
                    val target = pendingTarget
                    pendingTarget = null
                    result.success(target)
                }
                "openNotificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, app.packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${app.packageName}"))
                    }
                    activity?.startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun attachActivity(activity: MainActivity) {
        this.activity = activity
        channel.invokeMethod("activityAttached", null)
    }

    fun detachActivity(activity: MainActivity) {
        if (this.activity === activity) {
            this.activity = null
            resumed = false
        }
    }

    fun activityPaused(activity: MainActivity) {
        if (this.activity === activity) resumed = false
    }

    fun activityResumed(activity: MainActivity) {
        this.activity = activity
        resumed = true
        blockedUntilResume = false
        channel.invokeMethod("activityResumed", null)
    }

    fun openTransfer(target: String?) {
        val destination = transferTarget(target)
        if (navigationReady) channel.invokeMethod("notificationTap", destination)
        else pendingTarget = destination
    }

    private fun update(next: TransferSnapshot, result: MethodChannel.Result) {
        snapshot = next
        if (!next.active) {
            service?.stopFromHost()
            finishPending(false)
            result.success(false)
            return
        }
        service?.let {
            it.updateNotification(next)
            result.success(true)
            return
        }
        if (blockedUntilResume || !resumed) {
            result.success(false)
            return
        }
        pendingStarts.add(result)
        if (starting) return
        starting = true
        try {
            ContextCompat.startForegroundService(app, Intent(app, TransferService::class.java))
            requestNotificationPermission()
        } catch (error: RuntimeException) {
            // A foreground/background race waits for genuine onResume rather
            // than retrying on subsequent progress updates.
            Log.w("TransferHost", "Foreground transfer service start rejected", error)
            blockedUntilResume = true
            starting = false
            finishPending(false)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        val visibleActivity = activity ?: return
        val preferences = app.getSharedPreferences("transfer_notification", 0)
        if (preferences.getBoolean("requested", false)) return
        preferences.edit().putBoolean("requested", true).apply()
        if (ContextCompat.checkSelfPermission(app, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            visibleActivity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION)
        }
    }

    internal fun serviceStarted(service: TransferService) {
        this.service = service
        starting = false
        finishPending(true)
    }

    internal fun serviceStartRejected(error: RuntimeException) {
        Log.w("TransferHost", "Foreground promotion rejected", error)
        blockedUntilResume = true
        starting = false
        finishPending(false)
    }

    internal fun canPromoteService() = snapshot.active && !blockedUntilResume

    internal fun serviceStartAbandoned() {
        starting = false
        finishPending(false)
    }

    internal fun serviceStopped(service: TransferService) {
        if (this.service === service) {
            this.service = null
            finishPending(false)
        }
    }

    internal fun timedOut(service: TransferService) {
        // Block before notifying Dart, including during asynchronous work cleanup.
        blockedUntilResume = true
        service.stopFromHost()
        channel.invokeMethod("timeout", null)
    }

    private fun finishPending(running: Boolean) {
        val callbacks = pendingStarts.toList()
        pendingStarts.clear()
        callbacks.forEach { it.success(running) }
    }

    companion object {
        const val OPEN_TRANSFER = "shiro.hclient.OPEN_TRANSFER"
        const val TARGET = "transferTarget"
        private const val NOTIFICATION_PERMISSION = 8401
    }
}
