package com.andodevs.connectremote

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Centraliza los checks de permisos/ajustes que necesita el receptor. */
object PermissionHelper {

    fun hasBluetoothPermissions(ctx: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    fun isBluetoothEnabled(): Boolean {
        return try {
            BluetoothAdapter.getDefaultAdapter()?.isEnabled == true
        } catch (_: Exception) {
            false
        }
    }

    fun canDrawOverlays(ctx: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)
    }

    fun isAccessibilityServiceEnabled(ctx: Context): Boolean {
        val expectedComponent = "${ctx.packageName}/${RemoteAccessibilityService::class.java.name}"
        val enabledServices = try {
            Settings.Secure.getString(
                ctx.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
        } catch (_: Exception) {
            null
        } ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expectedComponent, ignoreCase = true)) return true
        }
        return false
    }

    fun isBatteryOptimizationIgnored(ctx: Context): Boolean {
        return try {
            val pm = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            pm.isIgnoringBatteryOptimizations(ctx.packageName)
        } catch (_: Exception) {
            true
        }
    }

    fun areNotificationsEnabled(ctx: Context): Boolean {
        return try {
            NotificationManagerCompat.from(ctx).areNotificationsEnabled()
        } catch (_: Exception) {
            true
        }
    }

    fun allCoreReady(ctx: Context): Boolean {
        return hasBluetoothPermissions(ctx) && canDrawOverlays(ctx) && isAccessibilityServiceEnabled(ctx)
    }

    fun overlaySettingsIntent(ctx: Context): android.content.Intent {
        return android.content.Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${ctx.packageName}")
        )
    }

    fun accessibilitySettingsIntent(): android.content.Intent {
        return android.content.Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
    }

    fun batteryOptimizationIntent(ctx: Context): android.content.Intent {
        return android.content.Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${ctx.packageName}")
        )
    }

    fun appNotificationSettingsIntent(ctx: Context): android.content.Intent {
        val intent = android.content.Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        intent.putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
        return intent
    }

    /**
     * Fallback universal: la pantalla "Información de la app". Útil cuando un
     * deep-link específico (overlay, accesibilidad, etc.) no resuelve en el
     * dispositivo (ROMs de TV-box personalizadas suelen renombrar u ocultar
     * esas pantallas dedicadas), permitiendo que el usuario busque el permiso
     * manualmente con el nombre que le haya puesto el fabricante.
     */
    fun appDetailsSettingsIntent(ctx: Context): android.content.Intent {
        return android.content.Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${ctx.packageName}")
        )
    }

    /**
     * En varios TV-box el permiso de superposición (SYSTEM_ALERT_WINDOW) no
     * tiene pantalla propia y aparece reutilizado bajo "Imagen en imagen".
     * Esa acción no forma parte de la API pública de Android (no existe como
     * constante en `Settings`); se usa el string literal que emplean algunas
     * ROMs de TV. Si el dispositivo no la implementa, `launchOrFallback` ya
     * captura el fallo y ofrece la alternativa de Información de la app.
     */
    fun pictureInPictureSettingsIntent(ctx: Context): android.content.Intent {
        return android.content.Intent(
            "android.settings.PICTURE_IN_PICTURE_SETTINGS",
            Uri.parse("package:${ctx.packageName}")
        )
    }

    fun bluetoothSettingsIntent(): android.content.Intent {
        return android.content.Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
    }

    /**
     * Desde Android 13 (API 33), los permisos sensibles (Accesibilidad,
     * notificaciones, etc.) de apps instaladas fuera de una tienda quedan
     * "restringidos": el interruptor aparece bloqueado/gris hasta que el
     * usuario lo desbloquea manualmente desde Información de la app. No hay
     * API para detectar este estado ni para desbloquearlo por código; solo
     * podemos avisar cuándo es probable que aplique.
     */
    fun mayHaveRestrictedSettings(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
}
