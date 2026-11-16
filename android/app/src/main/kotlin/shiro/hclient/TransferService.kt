package shiro.hclient

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class TransferService : Service() {
    private val app get() = application as HClientApplication
    private var host: TransferHost? = null
    private var foreground = false

    override fun onCreate() {
        super.onCreate()
        // Never boot Flutter or restore Dart tasks from a service.
        if (app.existingEngine == null) {
            stopSelf()
            return
        }
        val transferHost = app.transferHost
        host = transferHost
        promote(transferHost)
    }

    private fun promote(transferHost: TransferHost) {
        if (!transferHost.canPromoteService()) {
            transferHost.serviceStartAbandoned()
            stopSelf()
            return
        }
        createNotificationChannel()
        try {
            val notification = notification(transferHost.snapshot)
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            foreground = true
            transferHost.serviceStarted(this)
        } catch (error: RuntimeException) {
            transferHost.serviceStartRejected(error)
            stopFromHost()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A new session can arrive between stopSelf and actual service teardown.
        // Android may deliver that start to the existing service instance.
        if (!foreground) host?.let { promote(it) }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Stop immediately, independent of Dart network/encoding cancellation.
        host?.timedOut(this) ?: stopFromHost()
    }

    internal fun updateNotification(snapshot: TransferSnapshot) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(snapshot))
    }

    internal fun stopFromHost() {
        foreground = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        host?.serviceStopped(this)
    }

    override fun onDestroy() {
        foreground = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        host?.serviceStopped(this)
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL_ID, getString(R.string.transfer_channel_name), NotificationManager.IMPORTANCE_LOW)
            channel.setSound(null, null)
            channel.enableVibration(false)
            channel.setShowBadge(false)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun notification(snapshot: TransferSnapshot): Notification {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(TransferHost.OPEN_TRANSFER)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(TransferHost.TARGET, snapshot.target)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_transfer)
            .setContentTitle(snapshot.title)
            .setContentText(snapshot.text)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        if (snapshot.lines.isNotEmpty()) {
            val style = NotificationCompat.InboxStyle()
            snapshot.lines.forEach { style.addLine(it) }
            builder.setStyle(style)
        }
        val total = snapshot.total
        val progress = snapshot.progress
        if (total != null && total > 0 && progress != null) {
            // Android progress uses Int; byte totals may be much larger.
            val scale = maxOf(1L, (total - 1) / Int.MAX_VALUE + 1)
            builder.setProgress((total / scale).toInt(), (progress.coerceIn(0, total) / scale).toInt(), false)
        } else {
            builder.setProgress(0, 0, true)
        }
        return builder.build()
    }

    companion object {
        private const val CHANNEL_ID = "transfers"
        private const val NOTIFICATION_ID = 8401
    }
}
