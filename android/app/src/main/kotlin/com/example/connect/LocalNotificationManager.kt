package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.util.Collections

class LocalNotificationManager(private val context: Context) {
    private val appContext = context.applicationContext

    private var screenWakeEnabled: Boolean = false
    private var autoOpenEnabled: Boolean = false
    private var soundEnabled: Boolean = true

    init {
        ensureChannel()
    }

    fun updateSettings(
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean,
        soundEnabled: Boolean
    ) {
        this.screenWakeEnabled = screenWakeEnabled
        this.autoOpenEnabled = autoOpenEnabled
        this.soundEnabled = soundEnabled
        println("[local_notification] updateSettings screenWake=$screenWakeEnabled autoOpen=$autoOpenEnabled sound=$soundEnabled")
    }

    fun showNotification(
        title: String,
        body: String,
        packageName: String,
        appName: String,
        notificationId: String,
        soundEnabled: Boolean,
        vibrationEnabled: Boolean,
        customVibrationPattern: List<Long>?,
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean
    ) {
        val id = notificationId.ifBlank { System.currentTimeMillis().toString() }
        val numericId = (id.hashCode() and 0x7FFFFFFF)
        val nowMs = System.currentTimeMillis()

        if (isCancelled(id)) {
            println("[local_notification] skip cancelled id=$id")
            return
        }

        if (screenWakeEnabled) {
            wakeScreenOnce()
        }

        val openIntent = buildOpenIntent(
            action = NOTIFICATION_ACTION_OPEN,
            id = id,
            title = title,
            body = body,
            packageName = packageName,
            appName = appName,
            autoOpen = false,
            fromBackground = false,
            timestamp = nowMs,
            screenWakeEnabled = screenWakeEnabled
        )
        val contentPendingIntent = PendingIntent.getActivity(
            appContext,
            numericId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val deleteIntent = Intent(appContext, NotificationDeleteReceiver::class.java).apply {
            putExtra("notification_id", id)
        }
        val deletePendingIntent = PendingIntent.getBroadcast(
            appContext,
            numericId + 1,
            deleteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val builder = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(if (appName.isNotBlank()) appName else title.ifBlank { "Notificación" })
            .setContentText(if (title.isNotBlank()) title else body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body.ifBlank { title }))
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .setDeleteIntent(deletePendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (!soundEnabled) {
            builder.setSilent(true)
        }

        if (vibrationEnabled) {
            val pattern = customVibrationPattern?.takeIf { it.isNotEmpty() }?.toLongArray()
            if (pattern != null) {
                builder.setVibrate(pattern)
            } else {
                builder.setVibrate(longArrayOf(0, 200, 120, 200))
            }
        }

        if (autoOpenEnabled) {
            val autoOpenIntent = buildOpenIntent(
                action = NOTIFICATION_ACTION_AUTO_OPEN,
                id = id,
                title = title,
                body = body,
                packageName = packageName,
                appName = appName,
                autoOpen = true,
                fromBackground = true,
                timestamp = nowMs,
                screenWakeEnabled = screenWakeEnabled
            )
            val fullScreenPi = PendingIntent.getActivity(
                appContext,
                numericId + 2,
                autoOpenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            builder.setFullScreenIntent(fullScreenPi, true)
        }

        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(numericId, builder.build())
        println("[local_notification] show id=$id numericId=$numericId pkg='$packageName' app='$appName' title='${title.take(40)}'")

        if (autoOpenEnabled) {
            try {
                val autoOpenIntent = buildOpenIntent(
                    action = NOTIFICATION_ACTION_AUTO_OPEN,
                    id = id,
                    title = title,
                    body = body,
                    packageName = packageName,
                    appName = appName,
                    autoOpen = true,
                    fromBackground = true,
                    timestamp = nowMs,
                    screenWakeEnabled = screenWakeEnabled
                )
                appContext.startActivity(autoOpenIntent)
                println("[local_notification] autoOpen startActivity ok id=$id")
            } catch (t: Throwable) {
                println("[local_notification] autoOpen startActivity failed id=$id t=${t::class.java.simpleName} msg=${t.message}")
            }
        }
    }

    fun cancelNotification(notificationId: String) {
        val id = notificationId.ifBlank { return }
        val numericId = (id.hashCode() and 0x7FFFFFFF)
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(numericId)
        println("[local_notification] cancel id=$id numericId=$numericId")
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = nm.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
        nm.createNotificationChannel(channel)
    }

    private fun buildOpenIntent(
        action: String,
        id: String,
        title: String,
        body: String,
        packageName: String,
        appName: String,
        autoOpen: Boolean,
        fromBackground: Boolean,
        timestamp: Long,
        screenWakeEnabled: Boolean
    ): Intent {
        return Intent(appContext, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("navigate_to", "/notificaciones")
            putExtra(EXTRA_NOTIFICATION_DATA, id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("packageName", packageName)
            putExtra("appName", appName)
            putExtra("autoOpen", autoOpen)
            putExtra("fromBackground", fromBackground)
            putExtra("timestamp", timestamp)
            putExtra("screenWakeEnabled", screenWakeEnabled)
        }
    }

    private fun wakeScreenOnce() {
        try {
            val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "connect:local_notification"
            )
            wl.acquire(2000)
            try {
                wl.release()
            } catch (_: Throwable) {
            }
        } catch (t: Throwable) {
            println("[local_notification] wakeScreenOnce failed t=${t::class.java.simpleName} msg=${t.message}")
        }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    companion object {
        private const val CHANNEL_ID = "connect_receptor_notifications"
        private const val CHANNEL_NAME = "Notificaciones (Receptor)"

        const val NOTIFICATION_ACTION_OPEN = "com.example.connect.notification.OPEN"
        const val NOTIFICATION_ACTION_AUTO_OPEN = "com.example.connect.notification.AUTO_OPEN"
        const val EXTRA_NOTIFICATION_DATA = "notification_id"

        private val cancelledNotifications = Collections.synchronizedSet(mutableSetOf<String>())

        fun addToCancelledNotifications(notificationId: String) {
            if (notificationId.isBlank()) return
            cancelledNotifications.add(notificationId)
            println("[local_notification] add_cancelled id=$notificationId size=${cancelledNotifications.size}")
        }

        fun clearCancelledNotifications() {
            cancelledNotifications.clear()
            println("[local_notification] clear_cancelled")
        }

        private fun isCancelled(notificationId: String): Boolean {
            if (notificationId.isBlank()) return false
            return cancelledNotifications.contains(notificationId)
        }
    }
}

