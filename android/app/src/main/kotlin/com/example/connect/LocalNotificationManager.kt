package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.util.Collections

class LocalNotificationManager(private val context: Context) {
    private val appContext = context.applicationContext
    private val notificationManager =
        appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val settingsPrefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NOTIFICATION_SETTINGS, Context.MODE_PRIVATE)

    private fun sendBtDebug(source: String, message: String) {
        try {
            val obj = JSONObject()
            obj.put("type", "debug_log")
            obj.put("source", source)
            obj.put("message", message)
            obj.put("timestamp", System.currentTimeMillis())
            val i = Intent(appContext, BtClassicServerService::class.java)
                .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                .putExtra(BtClassicServerService.EXTRA_JSON, obj.toString())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) appContext.startForegroundService(i)
            else appContext.startService(i)
        } catch (_: Throwable) {
        }
    }

    private var screenWakeEnabled: Boolean = false
    private var autoOpenEnabled: Boolean = false
    private var soundEnabled: Boolean = true

    init {
        createOrRecreateNotificationChannel()
    }

    fun updateSettings(
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean,
        soundEnabled: Boolean
    ) {
        this.screenWakeEnabled = screenWakeEnabled
        this.autoOpenEnabled = autoOpenEnabled
        this.soundEnabled = soundEnabled
        persistSettings(screenWakeEnabled, autoOpenEnabled, soundEnabled)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                createOrRecreateNotificationChannel()
            }
        }
        println("[local_notification] updateSettings screenWake=$screenWakeEnabled autoOpen=$autoOpenEnabled sound=$soundEnabled")
        sendBtDebug("local_notif_settings", "updateSettings wake=$screenWakeEnabled autoOpen=$autoOpenEnabled sound=$soundEnabled")
    }

    fun showNotification(
        title: String,
        body: String,
        packageName: String,
        appName: String,
        appIcon: String,
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

        val notificationsEnabled = try {
            NotificationManagerCompat.from(appContext).areNotificationsEnabled()
        } catch (_: Throwable) {
            true
        }
        if (!notificationsEnabled) {
            println("[local_notification] blocked notificationsDisabled id=$id")
            sendBtDebug("notif_show", "blocked notificationsDisabled id='$id'")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val ch = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (ch == null) {
                    sendBtDebug("notif_show", "channel missing id='$id' willCreate=true")
                } else {
                    sendBtDebug("notif_show", "channel importance=${ch.importance} id='$id'")
                    if (ch.importance == NotificationManager.IMPORTANCE_NONE) {
                        println("[local_notification] blocked channelImportanceNone id=$id")
                        sendBtDebug("notif_show", "blocked channelImportanceNone id='$id'")
                        return
                    }
                }
            } catch (_: Throwable) {
            }
        }

        if (isCancelled(id)) {
            println("[local_notification] skip cancelled id=$id")
            sendBtDebug("notif_show", "skip_cancelled id='$id'")
            return
        }

        val effectiveScreenWakeEnabled = getCurrentScreenWakeEnabled() || screenWakeEnabled
        val effectiveAutoOpenEnabled = getCurrentAutoOpenEnabled() || autoOpenEnabled
        val effectiveSoundEnabled = getCurrentSoundEnabled() && soundEnabled

        println(
            "[local_notification] showNotification start id=$id numericId=$numericId sdk=${Build.VERSION.SDK_INT} autoOpenReq=$autoOpenEnabled wakeReq=$screenWakeEnabled autoOpenEff=$effectiveAutoOpenEnabled wakeEff=$effectiveScreenWakeEnabled soundEff=$effectiveSoundEnabled pkg='${packageName.take(80)}'"
        )
        sendBtDebug(
            "notif_show",
            "start id='$id' numericId=$numericId autoOpen=$effectiveAutoOpenEnabled wake=$effectiveScreenWakeEnabled sound=$effectiveSoundEnabled pkg='${packageName.take(60)}' title='${title.take(50)}'"
        )

        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
            createOrRecreateNotificationChannel()
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
            screenWakeEnabled = effectiveScreenWakeEnabled
        )
        val openPi = PendingIntent.getActivity(
            appContext,
            numericId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

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
            screenWakeEnabled = effectiveScreenWakeEnabled
        )
        val autoOpenPi = PendingIntent.getActivity(
            appContext,
            numericId + 2,
            autoOpenIntent,
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

        val displayTitle = title.ifBlank { appName.ifBlank { "Notificación" } }
        val largeIcon = decodeBase64Bitmap(appIcon)

        val builder = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(displayTitle)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setDeleteIntent(deletePendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (appName.isNotBlank() && appName != displayTitle) {
            builder.setContentInfo(appName)
        }
        if (largeIcon != null) {
            builder.setLargeIcon(largeIcon)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setSound(null)
            if (effectiveSoundEnabled) {
                playCustomSoundDirectly()
            } else {
                builder.setSilent(true)
            }
        } else {
            if (!effectiveSoundEnabled) {
                builder.setSilent(true)
            }
        }

        if (vibrationEnabled) {
            val pattern = customVibrationPattern?.takeIf { it.isNotEmpty() }?.toLongArray()
            if (pattern != null) {
                builder.setVibrate(pattern)
            } else {
                builder.setVibrate(longArrayOf(0, 200, 120, 200))
            }
        }

        if (effectiveAutoOpenEnabled) {
            builder.setCategory(NotificationCompat.CATEGORY_MESSAGE)
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
            builder.setContentIntent(openPi)
            if (effectiveScreenWakeEnabled) {
                try {
                    builder.setFullScreenIntent(autoOpenPi, true)
                    sendBtDebug("notif_show", "fullScreenIntent enabled id='$id'")
                    println("[local_notification] fullScreenIntent enabled id=$id")
                } catch (t: Throwable) {
                    println("[local_notification] fullScreenIntent failed id=$id t=${t::class.java.simpleName} msg=${t.message}")
                    sendBtDebug("notif_show", "fullScreenIntent failed id='$id' err='${t::class.java.simpleName}:${t.message ?: ""}'")
                }
            }
            scheduleAutoOpen(
                id = id,
                numericId = numericId,
                intent = autoOpenIntent,
                screenWakeEnabled = effectiveScreenWakeEnabled
            )
        } else {
            builder.setCategory(NotificationCompat.CATEGORY_MESSAGE)
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
            builder.setContentIntent(openPi)
        }

        try {
            notificationManager.notify(numericId, builder.build())
            println("[local_notification] notify ok id=$id numericId=$numericId")
        } catch (t: Throwable) {
            println("[local_notification] notify FAILED id=$id numericId=$numericId t=${t::class.java.simpleName} msg=${t.message}")
            sendBtDebug("notif_show", "notify FAILED id='$id' numericId=$numericId err='${t::class.java.simpleName}:${t.message ?: ""}'")
            return
        }
        println("[local_notification] show id=$id numericId=$numericId autoOpen=$effectiveAutoOpenEnabled pkg='$packageName' title='${title.take(40)}'")
        sendBtDebug("notif_show", "end id='$id' numericId=$numericId autoOpen=$effectiveAutoOpenEnabled")
    }

    private fun decodeBase64Bitmap(value: String): Bitmap? {
        val raw = value.trim()
        if (raw.isBlank()) return null
        val payload = raw.substringAfter(',', raw)
        return try {
            val bytes = Base64.decode(payload, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Throwable) {
            null
        }
    }

    fun cancelNotification(notificationId: String) {
        val id = notificationId.ifBlank { return }
        val numericId = (id.hashCode() and 0x7FFFFFFF)
        notificationManager.cancel(numericId)
        println("[local_notification] cancel id=$id numericId=$numericId")
    }

    private fun createOrRecreateNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            notificationManager.deleteNotificationChannel(CHANNEL_ID)
        } catch (_: Throwable) {
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableVibration(false)
            enableLights(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            setSound(null, null)
            setBypassDnd(false)
            setShowBadge(false)
            group = null
        }
        notificationManager.createNotificationChannel(channel)
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
            val baseFlags =
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            flags = if (screenWakeEnabled) {
                baseFlags or Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            } else {
                baseFlags
            }
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

    private fun scheduleAutoOpen(
        id: String,
        numericId: Int,
        intent: Intent,
        screenWakeEnabled: Boolean
    ) {
        val payload = JSONObject().apply {
            put("id", id)
            put("numericId", numericId)
            put("action", intent.action ?: "")
            put("extras", JSONObject().apply {
                put(EXTRA_NOTIFICATION_DATA, id)
                put("title", intent.getStringExtra("title") ?: "")
                put("body", intent.getStringExtra("body") ?: "")
                put("packageName", intent.getStringExtra("packageName") ?: "")
                put("appName", intent.getStringExtra("appName") ?: "")
                put("autoOpen", true)
                put("fromBackground", true)
                put("timestamp", intent.getLongExtra("timestamp", System.currentTimeMillis()))
                put("screenWakeEnabled", screenWakeEnabled)
            })
        }.toString()

        pendingAutoOpenJson = payload
        if (autoOpenScheduled) {
            sendBtDebug("auto_open", "coalesce pending id='$id' wake=$screenWakeEnabled")
            return
        }
        autoOpenScheduled = true
        sendBtDebug("auto_open", "scheduled id='$id' delayMs=260 wake=$screenWakeEnabled")
        Handler(Looper.getMainLooper()).postDelayed({
            autoOpenScheduled = false
            val json = pendingAutoOpenJson ?: return@postDelayed
            pendingAutoOpenJson = null
            tryPerformAutoOpen(json)
        }, 260L)
    }

    private fun tryPerformAutoOpen(json: String) {
        val nowMs = System.currentTimeMillis()
        if ((nowMs - lastAutoOpenAtMs) < 500L) {
            sendBtDebug("auto_open", "rate_limited deltaMs=${nowMs - lastAutoOpenAtMs}")
            return
        }

        val obj = try { JSONObject(json) } catch (_: Throwable) { null } ?: return
        val numericId = try { obj.optInt("numericId", -1) } catch (_: Throwable) { -1 }
        val extrasObj = obj.optJSONObject("extras") ?: JSONObject()
        val wakeEnabled = extrasObj.optBoolean("screenWakeEnabled", false)

        val id = extrasObj.optString(EXTRA_NOTIFICATION_DATA, "").trim()
        if (id.isEmpty()) return

        val km = appContext.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val pm = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isKeyguardLocked = try { km?.isKeyguardLocked == true } catch (_: Throwable) { false }
        val isDeviceSecure = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) km?.isDeviceSecure == true else km?.isKeyguardSecure == true
        } catch (_: Throwable) {
            false
        }
        val isInteractive = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) pm?.isInteractive == true else @Suppress("DEPRECATION") (pm?.isScreenOn == true)
        } catch (_: Throwable) {
            true
        }
        sendBtDebug(
            "auto_open",
            "attempt id='$id' keyguardLocked=$isKeyguardLocked deviceSecure=$isDeviceSecure interactive=$isInteractive numericId=$numericId"
        )
        println("[local_notification] autoOpen attempt id=$id keyguardLocked=$isKeyguardLocked deviceSecure=$isDeviceSecure interactive=$isInteractive wakeEnabled=$wakeEnabled sdk=${Build.VERSION.SDK_INT}")

        if (isKeyguardLocked && isDeviceSecure) {
            persistPendingAutoOpen(json)
            ensureUnlockReceiverRegistered()
            println("[local_notification] autoOpen deferred (secure lock) id=$id")
            sendBtDebug("auto_open", "deferred_secure_lock id='$id'")
            if (wakeEnabled && !isInteractive) {
                sendBtDebug("wake_screen", "secure_lock wake requested id='$id'")
                Handler(Looper.getMainLooper()).postDelayed({
                    wakeUpScreenConservative()
                }, 80L)
            }
            return
        }

        val launch = buildIntentFromExtras(extrasObj, NOTIFICATION_ACTION_AUTO_OPEN)
        try {
            val reqCode = if (numericId >= 0) numericId else (id.hashCode() and 0x7FFFFFFF)
            val pi = PendingIntent.getActivity(
                appContext,
                reqCode,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            try {
                pi.send()
                sendBtDebug("auto_open", "pendingIntent send ok id='$id' reqCode=$reqCode")
                println("[local_notification] autoOpen pendingIntent.send ok id=$id reqCode=$reqCode")
            } catch (_: PendingIntent.CanceledException) {
                appContext.startActivity(launch)
                sendBtDebug("auto_open", "pendingIntent canceled -> startActivity ok id='$id' reqCode=$reqCode")
                println("[local_notification] autoOpen pendingIntent canceled -> startActivity ok id=$id reqCode=$reqCode")
            }
            lastAutoOpenAtMs = nowMs
            sendBtDebug("auto_open", "triggered id='$id' reqCode=$reqCode")
        } catch (t: Throwable) {
            println("[local_notification] autoOpen startActivity failed id=$id t=${t::class.java.simpleName} msg=${t.message}")
            sendBtDebug("auto_open", "startActivity failed id='$id' err='${t::class.java.simpleName}:${t.message ?: ""}'")
            return
        }

        if (wakeEnabled) {
            if (!isInteractive) {
                sendBtDebug("wake_screen", "requested id='$id' willWake=true")
                Handler(Looper.getMainLooper()).postDelayed({
                    wakeUpScreenConservative()
                }, 80L)
            } else {
                sendBtDebug("wake_screen", "requested id='$id' willWake=false reason=interactive")
            }
        } else {
            sendBtDebug("wake_screen", "disabled id='$id'")
        }
    }

    private fun buildIntentFromExtras(extrasObj: JSONObject, action: String): Intent {
        return Intent(appContext, MainActivity::class.java).apply {
            this.action = action
            val baseFlags =
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            val wakeEnabled = extrasObj.optBoolean("screenWakeEnabled", false)
            flags = if (wakeEnabled) {
                baseFlags or Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            } else {
                baseFlags
            }
            putExtra(EXTRA_NOTIFICATION_DATA, extrasObj.optString(EXTRA_NOTIFICATION_DATA, ""))
            putExtra("title", extrasObj.optString("title", ""))
            putExtra("body", extrasObj.optString("body", ""))
            putExtra("packageName", extrasObj.optString("packageName", ""))
            putExtra("appName", extrasObj.optString("appName", ""))
            putExtra("autoOpen", extrasObj.optBoolean("autoOpen", true))
            putExtra("fromBackground", extrasObj.optBoolean("fromBackground", true))
            putExtra("timestamp", try { extrasObj.optLong("timestamp", System.currentTimeMillis()) } catch (_: Throwable) { System.currentTimeMillis() })
            putExtra("screenWakeEnabled", extrasObj.optBoolean("screenWakeEnabled", false))
        }
    }

    private fun persistPendingAutoOpen(json: String) {
        try {
            val prefs = appContext.getSharedPreferences(PREFS_NOTIFICATION_SETTINGS, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_PENDING_AUTO_OPEN_JSON, json).apply()
        } catch (_: Throwable) {
        }
    }

    private fun takePendingAutoOpen(): String? {
        return try {
            val prefs = appContext.getSharedPreferences(PREFS_NOTIFICATION_SETTINGS, Context.MODE_PRIVATE)
            val s = prefs.getString(KEY_PENDING_AUTO_OPEN_JSON, null)
            prefs.edit().remove(KEY_PENDING_AUTO_OPEN_JSON).apply()
            s
        } catch (_: Throwable) {
            null
        }
    }

    private fun ensureUnlockReceiverRegistered() {
        if (unlockReceiverRegistered) return
        unlockReceiverRegistered = true
        try {
            appContext.registerReceiver(
                unlockReceiver,
                android.content.IntentFilter(Intent.ACTION_USER_PRESENT)
            )
        } catch (_: Throwable) {
            unlockReceiverRegistered = false
        }
    }

    private val unlockReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != Intent.ACTION_USER_PRESENT) return
            val json = takePendingAutoOpen() ?: return
            try {
                appContext.unregisterReceiver(this)
            } catch (_: Throwable) {
            }
            unlockReceiverRegistered = false
            Handler(Looper.getMainLooper()).postDelayed({
                tryPerformAutoOpen(json)
            }, 220L)
        }
    }

    private fun wakeScreenOnce() {
        try {
            sendBtDebug("wake_screen", "wakeScreenOnce start")
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
            sendBtDebug("wake_screen", "wakeScreenOnce end")
        } catch (t: Throwable) {
            println("[local_notification] wakeScreenOnce failed t=${t::class.java.simpleName} msg=${t.message}")
            sendBtDebug("wake_screen", "wakeScreenOnce failed err='${t::class.java.simpleName}:${t.message ?: ""}'")
        }
    }

    private fun wakeUpScreenConservative() {
        try {
            println("[local_notification] wakeUpScreenConservative start sdk=${Build.VERSION.SDK_INT}")
            val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm.isInteractive
            } else {
                @Suppress("DEPRECATION")
                pm.isScreenOn
            }
            if (isInteractive) return

            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                sendBtDebug("wake_screen", "wakeUpScreenConservative android8 start")
                println("[local_notification] wakeUpScreenConservative android8 path")
                @Suppress("DEPRECATION")
                val wl = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "connect:local_notification_android8"
                )
                wl.acquire(2000)
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val intent = Intent(appContext, MainActivity::class.java).apply {
                            action = "WAKE_SCREEN_ACTION"
                            flags =
                                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            putExtra("wakeScreenOnly", true)
                            putExtra("screenWakeEnabled", true)
                            putExtra("timestamp", System.currentTimeMillis())
                        }
                        appContext.startActivity(intent)
                        println("[local_notification] wakeUpScreenConservative android8 startActivity ok")
                    } catch (_: Throwable) {
                        println("[local_notification] wakeUpScreenConservative android8 startActivity failed")
                    }
                }, 300L)
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        if (wl.isHeld) wl.release()
                    } catch (_: Throwable) {
                    }
                }, 1500L)
                return
            }

            wakeScreenOnce()
        } catch (t: Throwable) {
            println("[local_notification] wakeUpScreenConservative failed t=${t::class.java.simpleName} msg=${t.message}")
            sendBtDebug("wake_screen", "wakeUpScreenConservative failed err='${t::class.java.simpleName}:${t.message ?: ""}'")
        }
    }

    private fun playCustomSoundDirectly() {
        try {
            val act = MainActivity.instance ?: return
            act.runOnUiThread {
                try {
                    act.soundChannel.invokeMethod("playCustomSound", null)
                } catch (_: Throwable) {
                }
            }
        } catch (_: Throwable) {
        }
    }

    private fun persistSettings(
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean,
        soundEnabled: Boolean
    ) {
        try {
            settingsPrefs.edit()
                .putBoolean(KEY_SCREEN_WAKE_ENABLED, screenWakeEnabled)
                .putBoolean(KEY_AUTO_OPEN_ENABLED, autoOpenEnabled)
                .putBoolean(KEY_SOUND_ENABLED, soundEnabled)
                .apply()
        } catch (_: Throwable) {
        }
    }

    private fun getCurrentScreenWakeEnabled(): Boolean {
        return try {
            settingsPrefs.getBoolean(KEY_SCREEN_WAKE_ENABLED, screenWakeEnabled)
        } catch (_: Throwable) {
            screenWakeEnabled
        }
    }

    private fun getCurrentAutoOpenEnabled(): Boolean {
        return try {
            settingsPrefs.getBoolean(KEY_AUTO_OPEN_ENABLED, autoOpenEnabled)
        } catch (_: Throwable) {
            autoOpenEnabled
        }
    }

    private fun getCurrentSoundEnabled(): Boolean {
        return try {
            settingsPrefs.getBoolean(KEY_SOUND_ENABLED, soundEnabled)
        } catch (_: Throwable) {
            soundEnabled
        }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    companion object {
        private const val PREFS_NOTIFICATION_SETTINGS = "flutter.notification_settings"
        private const val KEY_SCREEN_WAKE_ENABLED = "flutter.screenWakeEnabled"
        private const val KEY_AUTO_OPEN_ENABLED = "flutter.autoOpenEnabled"
        private const val KEY_SOUND_ENABLED = "flutter.soundEnabled"
        private const val KEY_PENDING_AUTO_OPEN_JSON = "flutter.pendingAutoOpenJson"

        private const val CHANNEL_ID = "receptor_notifications_channel"
        private const val CHANNEL_NAME = "Notificaciones del Receptor"
        private const val CHANNEL_DESCRIPTION =
            "Canal para mostrar notificaciones recibidas en el receptor"

        const val NOTIFICATION_ACTION_OPEN = "com.example.connect.notification.OPEN"
        const val NOTIFICATION_ACTION_AUTO_OPEN = "com.example.connect.notification.AUTO_OPEN"
        const val EXTRA_NOTIFICATION_DATA = "notification_id"

        private val cancelledNotifications = Collections.synchronizedSet(mutableSetOf<String>())
        @Volatile private var lastAutoOpenAtMs: Long = 0L
        @Volatile private var autoOpenScheduled: Boolean = false
        @Volatile private var pendingAutoOpenJson: String? = null
        @Volatile private var unlockReceiverRegistered: Boolean = false

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
