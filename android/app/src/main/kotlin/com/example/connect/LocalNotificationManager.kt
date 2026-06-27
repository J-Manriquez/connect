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
import org.json.JSONArray
import org.json.JSONObject
import java.util.Collections

class LocalNotificationManager(private val context: Context) {
    private val appContext = context.applicationContext
    private val notificationManager =
        appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val settingsPrefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NOTIFICATION_SETTINGS, Context.MODE_PRIVATE)

    private fun sendBtDebug(source: String, message: String) {
        // Llamada directa y sincrona (sin Intent/startForegroundService), igual
        // al patron usado por media_state: evita el rate-limit de Android sobre
        // startForegroundService cuando se loguea con frecuencia.
        try {
            BtClassicServerService.sendDebugLogToPeers(source, message)
        } catch (_: Throwable) {
        }
    }

    private var screenWakeEnabled: Boolean = false
    private var autoOpenEnabled: Boolean = false
    private var soundEnabled: Boolean = true

    private var cachedBlockRulesAtMs: Long = 0L
    private var cachedBlockRules: List<Map<String, String>> = emptyList()
    private var cachedSentRepliesAtMs: Long = 0L
    private var cachedSentReplies: List<Map<String, String>> = emptyList()

    private fun normalizeForMatch(s: String): String {
        var out = s.trim().lowercase()
        if (out.isBlank()) return ""
        out = out
            .replace(Regex("[áàäâ]"), "a")
            .replace(Regex("[éèëê]"), "e")
            .replace(Regex("[íìïî]"), "i")
            .replace(Regex("[óòöô]"), "o")
            .replace(Regex("[úùüû]"), "u")
            .replace("ñ", "n")
        out = out.replace(Regex("[^a-z0-9]+"), " ")
        out = out.replace(Regex("\\s+"), " ").trim()
        return out
    }

    private fun loadCustomBlockRules(nowMs: Long): List<Map<String, String>> {
        if (cachedBlockRulesAtMs > 0L && (nowMs - cachedBlockRulesAtMs) < 1500L) {
            return cachedBlockRules
        }
        cachedBlockRulesAtMs = nowMs
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.custom_block_rules_v1", "[]") ?: "[]"
            val arr = JSONArray(raw)
            val out = ArrayList<Map<String, String>>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val pkg = obj.optString("pkg", "").trim()
                if (pkg.isBlank()) continue
                val titleNorm = obj.optString("titleNorm", "").trim()
                val textNorm = obj.optString("textNorm", "").trim()
                out.add(
                    mapOf(
                        "pkg" to pkg,
                        "titleNorm" to titleNorm,
                        "textNorm" to textNorm
                    )
                )
            }
            cachedBlockRules = out
            out
        } catch (_: Throwable) {
            cachedBlockRules = emptyList()
            emptyList()
        }
    }

    private fun loadRecentSentReplies(nowMs: Long): List<Map<String, String>> {
        if (cachedSentRepliesAtMs > 0L && (nowMs - cachedSentRepliesAtMs) < 1500L) {
            return cachedSentReplies
        }
        cachedSentRepliesAtMs = nowMs
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.recent_sent_replies_v1", "[]") ?: "[]"
            val arr = JSONArray(raw)
            val out = ArrayList<Map<String, String>>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val pkg = obj.optString("pkg", "").trim()
                val textNorm = obj.optString("textNorm", "").trim()
                val titleNorm = obj.optString("titleNorm", "").trim()
                val tsMs = obj.optLong("tsMs", 0L)
                if (pkg.isBlank() || textNorm.isBlank() || tsMs <= 0L) continue
                if ((nowMs - tsMs) > 2 * 60 * 1000L) continue
                out.add(
                    mapOf(
                        "pkg" to pkg,
                        "titleNorm" to titleNorm,
                        "textNorm" to textNorm,
                        "tsMs" to tsMs.toString()
                    )
                )
            }
            cachedSentReplies = out
            out
        } catch (_: Throwable) {
            cachedSentReplies = emptyList()
            emptyList()
        }
    }

    private fun shouldBlockByCustomRules(
        nowMs: Long,
        packageName: String,
        title: String,
        body: String
    ): Boolean {
        val rules = loadCustomBlockRules(nowMs)
        if (rules.isEmpty()) return false
        val pkg = packageName.trim()
        if (pkg.isBlank()) return false
        val titleNorm = normalizeForMatch(title)
        val bodyNorm = normalizeForMatch(body)
        for (r in rules) {
            val rpkg = (r["pkg"] ?: "").trim()
            if (rpkg != pkg) continue
            val rtitle = (r["titleNorm"] ?: "").trim()
            val rtext = (r["textNorm"] ?: "").trim()
            val titleOk = rtitle.isBlank() || (titleNorm.isNotBlank() && titleNorm.contains(rtitle))
            val textOk = rtext.isBlank() || (bodyNorm.isNotBlank() && bodyNorm.contains(rtext))
            if (titleOk && textOk) return true
        }
        return false
    }

    private fun shouldSuppressOutgoingEcho(
        nowMs: Long,
        packageName: String,
        title: String,
        body: String
    ): Boolean {
        val list = loadRecentSentReplies(nowMs)
        if (list.isEmpty()) return false
        val pkg = packageName.trim()
        if (pkg.isBlank()) return false
        val titleNorm = normalizeForMatch(title)
        val bodyNorm = normalizeForMatch(body)
        if (bodyNorm.isBlank()) return false
        for (e in list) {
            val epkg = (e["pkg"] ?: "").trim()
            if (epkg != pkg) continue
            val etext = (e["textNorm"] ?: "").trim()
            if (etext.isBlank()) continue
            val ets = (e["tsMs"] ?: "0").toLongOrNull() ?: 0L
            if (ets <= 0L) continue
            if ((nowMs - ets) > 20000L) continue
            val etitle = (e["titleNorm"] ?: "").trim()
            val titleOk = etitle.isBlank() || titleNorm.isBlank() || titleNorm.contains(etitle) || etitle.contains(titleNorm)
            val textOk = bodyNorm.contains(etext) || etext.contains(bodyNorm)
            if (titleOk && textOk) return true
        }
        return false
    }

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

        val displayTitle = title.ifBlank { appName.ifBlank { "Notificación" } }
        if (shouldSuppressOutgoingEcho(nowMs, packageName, displayTitle, body)) {
            sendBtDebug("notif_show", "blocked_outgoing_echo id='$id' pkg='${packageName.take(60)}' title='${displayTitle.take(50)}'")
            return
        }
        if (shouldBlockByCustomRules(nowMs, packageName, displayTitle, body)) {
            sendBtDebug("notif_show", "blocked_custom_rule id='$id' pkg='${packageName.take(60)}' title='${displayTitle.take(50)}'")
            return
        }
        val groupKey = buildGroupKey(packageName, displayTitle)
        val numericId = (groupKey.hashCode() and 0x7FFFFFFF)
        val groupState = updateGroupState(groupKey, id, body, nowMs)
        persistGroupKeyForId(id, groupKey)

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

        val largeIcon = decodeBase64Bitmap(appIcon)

        val builder = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(displayTitle)
            .setContentText(groupState.lastBody)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    buildGroupedBodyText(groupState.prevBody, groupState.lastBody)
                )
            )
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
            builder.setContentIntent(autoOpenPi)
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

        if (effectiveScreenWakeEnabled && !effectiveAutoOpenEnabled) {
            try {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                    pm.isInteractive
                } else {
                    @Suppress("DEPRECATION")
                    pm.isScreenOn
                }
                sendBtDebug("wake_screen", "wakeOnly requested id='$id' interactive=$isInteractive")
                if (!isInteractive) {
                    Handler(Looper.getMainLooper()).postDelayed({
                        wakeUpScreenConservative(false)
                    }, 80L)
                }
            } catch (_: Throwable) {
            }
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

    private fun persistGroupKeyForId(id: String, groupKey: String) {
        if (id.isBlank() || groupKey.isBlank()) return
        try {
            idToGroupKey[id] = groupKey
            settingsPrefs.edit().putString(KEY_GROUP_KEY_PREFIX + id, groupKey).apply()
        } catch (_: Throwable) {
        }
    }

    private fun takeGroupKeyForId(id: String): String? {
        if (id.isBlank()) return null
        val existing = idToGroupKey[id]
        if (!existing.isNullOrBlank()) return existing
        return try {
            val s = settingsPrefs.getString(KEY_GROUP_KEY_PREFIX + id, null)
            if (!s.isNullOrBlank()) {
                idToGroupKey[id] = s
            }
            s
        } catch (_: Throwable) {
            null
        }
    }

    fun cancelNotification(notificationId: String) {
        val id = notificationId.ifBlank { return }
        val groupKey = takeGroupKeyForId(id)
        val numericId =
            if (groupKey.isNullOrBlank()) (id.hashCode() and 0x7FFFFFFF) else (groupKey.hashCode() and 0x7FFFFFFF)
        markProgrammaticCancel(id)
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
        val isAutoOpen = action == NOTIFICATION_ACTION_AUTO_OPEN
        val targetClass = if (action == NOTIFICATION_ACTION_AUTO_OPEN) {
            AutoOpenConversationActivity::class.java
        } else {
            MainActivity::class.java
        }
        try {
            val fb = isFloatingBallEnabled()
            sendBtDebug(
                "auto_open",
                "build_open_intent action='$action' target='${targetClass.simpleName}' fromBg=$fromBackground fbPref=$fb wake=$screenWakeEnabled"
            )
        } catch (_: Throwable) {
        }
        return Intent(appContext, targetClass).apply {
            this.action = action
            val baseFlags = if (isAutoOpen) {
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            } else {
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            flags = if (!isAutoOpen && screenWakeEnabled) {
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
        try {
            val untilMs = System.currentTimeMillis() + 6000L
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.skip_auto_redirect_once", true)
                .putLong("flutter.auto_open_block_until_ms", untilMs)
                .apply()
            sendBtDebug("auto_open", "schedule_set_block untilMs=$untilMs id='$id'")
        } catch (_: Throwable) {
        }
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

        try {
            val untilMs = nowMs + 6000L
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.skip_auto_redirect_once", true)
                .putLong("flutter.auto_open_block_until_ms", untilMs)
                .apply()
            sendBtDebug("auto_open", "set_block untilMs=$untilMs id='$id'")
        } catch (_: Throwable) {
        }

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
                    wakeUpScreenConservative(false)
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
                    wakeUpScreenConservative(false)
                }, 80L)
            } else {
                sendBtDebug("wake_screen", "requested id='$id' willWake=false reason=interactive")
            }
        } else {
            sendBtDebug("wake_screen", "disabled id='$id'")
        }
    }

    private fun buildIntentFromExtras(extrasObj: JSONObject, action: String): Intent {
        val fromBackground = extrasObj.optBoolean("fromBackground", true)
        val isAutoOpen = action == NOTIFICATION_ACTION_AUTO_OPEN
        val targetClass = if (action == NOTIFICATION_ACTION_AUTO_OPEN) {
            AutoOpenConversationActivity::class.java
        } else {
            MainActivity::class.java
        }
        try {
            val fb = isFloatingBallEnabled()
            sendBtDebug(
                "auto_open",
                "build_intent action='$action' target='${targetClass.simpleName}' fromBg=$fromBackground fbPref=$fb"
            )
        } catch (_: Throwable) {
        }

        return Intent(appContext, targetClass).apply {
            this.action = action
            val wakeEnabled = extrasObj.optBoolean("screenWakeEnabled", false)
            val baseFlags = if (isAutoOpen) {
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            } else {
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            flags = if (!isAutoOpen && wakeEnabled) {
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
            putExtra("fromBackground", fromBackground)
            putExtra("timestamp", try { extrasObj.optLong("timestamp", System.currentTimeMillis()) } catch (_: Throwable) { System.currentTimeMillis() })
            putExtra("screenWakeEnabled", extrasObj.optBoolean("screenWakeEnabled", false))
        }
    }

    private fun isFloatingBallEnabled(): Boolean {
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.floating_ball_enabled", false)
        } catch (_: Throwable) {
            false
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

    private fun wakeUpScreenConservative(allowActivityLaunch: Boolean = true) {
        try {
            println("[local_notification] wakeUpScreenConservative start sdk=${Build.VERSION.SDK_INT} allowActivityLaunch=$allowActivityLaunch")
            val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm.isInteractive
            } else {
                @Suppress("DEPRECATION")
                pm.isScreenOn
            }
            if (isInteractive) return

            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                if (!allowActivityLaunch) {
                    sendBtDebug("wake_screen", "wakeUpScreenConservative android8 noActivity")
                    wakeScreenOnce()
                    return
                }
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
        private const val KEY_GROUP_KEY_PREFIX = "flutter.groupKeyForId."

        private const val CHANNEL_ID = "receptor_notifications_channel"
        private const val CHANNEL_NAME = "Notificaciones del Receptor"
        private const val CHANNEL_DESCRIPTION =
            "Canal para mostrar notificaciones recibidas en el receptor"

        const val NOTIFICATION_ACTION_OPEN = "com.example.connect.notification.OPEN"
        const val NOTIFICATION_ACTION_AUTO_OPEN = "com.example.connect.notification.AUTO_OPEN"
        const val EXTRA_NOTIFICATION_DATA = "notification_id"

        private val cancelledNotifications = Collections.synchronizedSet(mutableSetOf<String>())
        private val programmaticCancelledNotifications =
            Collections.synchronizedSet(mutableSetOf<String>())
        private val groupStates =
            Collections.synchronizedMap(mutableMapOf<String, GroupState>())
        private val idToGroupKey =
            Collections.synchronizedMap(mutableMapOf<String, String>())
        @Volatile private var lastAutoOpenAtMs: Long = 0L
        @Volatile private var autoOpenScheduled: Boolean = false
        @Volatile private var pendingAutoOpenJson: String? = null
        @Volatile private var unlockReceiverRegistered: Boolean = false

        private data class GroupState(
            var lastId: String,
            var lastBody: String,
            var prevBody: String?,
            var updatedAtMs: Long
        )

        private fun buildGroupKey(packageName: String, title: String): String {
            val pkg = packageName.trim()
            val t = title.trim()
            return (pkg + "|" + t).lowercase()
        }

        private fun updateGroupState(
            groupKey: String,
            id: String,
            body: String,
            nowMs: Long
        ): GroupState {
            val trimmedBody = body.trim()
            val current = groupStates[groupKey]
            if (current == null) {
                val gs = GroupState(
                    lastId = id,
                    lastBody = trimmedBody,
                    prevBody = null,
                    updatedAtMs = nowMs
                )
                groupStates[groupKey] = gs
                idToGroupKey[id] = groupKey
                return gs
            }

            if (trimmedBody.isNotEmpty() && trimmedBody != current.lastBody) {
                current.prevBody = current.lastBody
                current.lastBody = trimmedBody
            }
            current.lastId = id
            current.updatedAtMs = nowMs
            idToGroupKey[id] = groupKey
            return current
        }

        private fun buildGroupedBodyText(prevBody: String?, lastBody: String): String {
            val last = lastBody.trim()
            val prev = prevBody?.trim().orEmpty()
            if (prev.isEmpty() || prev == last) return last
            return prev + "\n" + last
        }

        fun addToCancelledNotifications(notificationId: String) {
            if (notificationId.isBlank()) return
            cancelledNotifications.add(notificationId)
            println("[local_notification] add_cancelled id=$notificationId size=${cancelledNotifications.size}")
        }

        fun consumeProgrammaticCancel(notificationId: String): Boolean {
            if (notificationId.isBlank()) return false
            return programmaticCancelledNotifications.remove(notificationId)
        }

        fun clearCancelledNotifications() {
            cancelledNotifications.clear()
            println("[local_notification] clear_cancelled")
        }

        private fun markProgrammaticCancel(notificationId: String) {
            if (notificationId.isBlank()) return
            programmaticCancelledNotifications.add(notificationId)
        }

        private fun isCancelled(notificationId: String): Boolean {
            if (notificationId.isBlank()) return false
            return cancelledNotifications.contains(notificationId)
        }
    }
}
