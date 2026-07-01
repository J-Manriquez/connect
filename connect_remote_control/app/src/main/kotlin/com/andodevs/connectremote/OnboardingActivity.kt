package com.andodevs.connectremote

import android.bluetooth.BluetoothAdapter
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat

/**
 * Guía paso a paso para conceder todos los permisos que el receptor necesita.
 *
 * En TV-box/smart TV con ROMs personalizadas, varios de estos permisos no
 * tienen la pantalla "estándar" de Android, o la tienen renombrada:
 *  - El permiso de superposición (SYSTEM_ALERT_WINDOW) a veces se expone solo
 *    bajo "Imagen en imagen".
 *  - "Hacer visible" (discoverable) puede no tener diálogo en absoluto si el
 *    stack Bluetooth del fabricante no lo implementa; en ese caso basta con
 *    emparejar por los Ajustes de Bluetooth normales.
 *  - Desde Android 13, accesibilidad/notificaciones de apps fuera de una
 *    tienda quedan "restringidas" (interruptor bloqueado) hasta que el
 *    usuario lo desbloquea manualmente en Información de la app.
 * Por eso cada paso muestra su estado en vivo y, si un deep-link falla,
 * se ofrece de inmediato la alternativa "Información de la app".
 */
class OnboardingActivity : AppCompatActivity() {

    private lateinit var statusBluetooth: TextView
    private lateinit var statusOverlay: TextView
    private lateinit var statusAccessibility: TextView
    private lateinit var hintAccessibilityRestricted: TextView
    private lateinit var seekCursorSize: SeekBar
    private lateinit var tvCursorSizeLabel: TextView

    companion object {
        const val PREFS_NAME = "connect_remote_prefs"
        // progress 0..8, centro=4 → dp: 16,20,24,28,32(default),40,48,56,64
        private val CURSOR_SIZE_DP = intArrayOf(16, 20, 24, 28, 32, 40, 48, 56, 64)
        const val KEY_CURSOR_SIZE_IDX = "cursor_size_idx"
        private const val REQ_BT = 9001
        private const val REQ_NOTIF = 9002

        fun loadCursorSizeDp(context: Context): Int {
            val idx = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getInt(KEY_CURSOR_SIZE_IDX, 4)
            return CURSOR_SIZE_DP[idx.coerceIn(0, CURSOR_SIZE_DP.size - 1)]
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_onboarding)

        statusBluetooth = findViewById(R.id.statusBluetooth)
        statusOverlay = findViewById(R.id.statusOverlay)
        statusAccessibility = findViewById(R.id.statusAccessibility)
        hintAccessibilityRestricted = findViewById(R.id.hintAccessibilityRestricted)
        seekCursorSize = findViewById(R.id.seekCursorSize)
        tvCursorSizeLabel = findViewById(R.id.tvCursorSizeLabel)

        findViewById<Button>(R.id.btnPairing).setOnClickListener {
            launchOrFallback(PermissionHelper.bluetoothSettingsIntent(), "Ajustes de Bluetooth")
        }
        findViewById<Button>(R.id.btnBluetooth).setOnClickListener {
            requestBluetoothPermissions()
        }
        findViewById<Button>(R.id.btnDiscoverable).setOnClickListener {
            makeDiscoverable()
        }
        findViewById<Button>(R.id.btnOverlay).setOnClickListener {
            launchOrFallback(PermissionHelper.overlaySettingsIntent(this), "Permitir superposición")
        }
        findViewById<Button>(R.id.btnPip).setOnClickListener {
            launchOrFallback(
                PermissionHelper.pictureInPictureSettingsIntent(this),
                "Imagen en imagen"
            )
        }
        findViewById<Button>(R.id.btnAccessibility).setOnClickListener {
            launchOrFallback(PermissionHelper.accessibilitySettingsIntent(), "Accesibilidad")
        }
        findViewById<Button>(R.id.btnBattery).setOnClickListener {
            launchOrFallback(
                PermissionHelper.batteryOptimizationIntent(this),
                "Optimización de batería"
            )
        }
        findViewById<Button>(R.id.btnNotifications).setOnClickListener {
            launchOrFallback(
                PermissionHelper.appNotificationSettingsIntent(this),
                "Notificaciones"
            )
        }
        findViewById<Button>(R.id.btnAppDetails).setOnClickListener {
            try {
                startActivity(PermissionHelper.appDetailsSettingsIntent(this))
            } catch (_: Exception) {
                Toast.makeText(
                    this,
                    "Este dispositivo no tiene una pantalla de información de apps accesible.",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
        findViewById<Button>(R.id.btnDone).setOnClickListener {
            finish()
        }

        hintAccessibilityRestricted.visibility =
            if (PermissionHelper.mayHaveRestrictedSettings()) {
                android.view.View.VISIBLE
            } else {
                android.view.View.GONE
            }

        // SeekBar de tamaño del cursor
        val savedIdx = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_CURSOR_SIZE_IDX, 4)
        seekCursorSize.progress = savedIdx
        updateCursorSizeLabel(savedIdx)
        seekCursorSize.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
                updateCursorSizeLabel(progress)
            }
            override fun onStartTrackingTouch(sb: SeekBar) {}
            override fun onStopTrackingTouch(sb: SeekBar) {
                val idx = sb.progress
                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                    .putInt(KEY_CURSOR_SIZE_IDX, idx).apply()
                // Aplicar en caliente al cursor si el servicio está corriendo
                RemoteServerService.instance?.controller?.cursorOverlay?.let { overlay ->
                    overlay.cursorSizeDp = CURSOR_SIZE_DP[idx.coerceIn(0, CURSOR_SIZE_DP.size - 1)]
                    overlay.applyCursorSize()
                }
            }
        })
    }

    private fun updateCursorSizeLabel(idx: Int) {
        val dp = CURSOR_SIZE_DP[idx.coerceIn(0, CURSOR_SIZE_DP.size - 1)]
        val label = when (idx) {
            4    -> "Tamaño: normal (${dp}dp)"
            in 0..3 -> "Tamaño: pequeño (${dp}dp)"
            else -> "Tamaño: grande (${dp}dp)"
        }
        tvCursorSizeLabel.text = label
    }

    override fun onResume() {
        super.onResume()
        refreshStatuses()
    }

    private fun refreshStatuses() {
        setStatus(
            statusBluetooth,
            "1. Permisos de Bluetooth",
            PermissionHelper.hasBluetoothPermissions(this)
        )
        setStatus(
            statusOverlay,
            "3. Permitir superposición (cursor)",
            PermissionHelper.canDrawOverlays(this)
        )
        setStatus(
            statusAccessibility,
            "4. Activar servicio de accesibilidad",
            PermissionHelper.isAccessibilityServiceEnabled(this)
        )
    }

    private fun setStatus(view: TextView, label: String, granted: Boolean) {
        if (granted) {
            view.text = "$label — ✓ concedido"
            view.setTextColor(Color.parseColor("#2E7D32"))
        } else {
            view.text = "$label — ✗ pendiente"
            view.setTextColor(Color.parseColor("#C62828"))
        }
    }

    /**
     * Intenta abrir el Intent dado. Si el dispositivo no tiene ninguna
     * pantalla que lo resuelva (común en ROMs de TV-box que renombran u
     * ocultan ajustes), se informa de inmediato y se ofrece abrir
     * "Información de la app" como alternativa para buscarlo manualmente.
     */
    private fun launchOrFallback(intent: Intent, label: String) {
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            showFallbackDialog(label)
        } catch (_: Exception) {
            showFallbackDialog(label)
        }
    }

    private fun showFallbackDialog(label: String) {
        AlertDialog.Builder(this)
            .setTitle("\"$label\" no está disponible aquí")
            .setMessage(
                "Este dispositivo no tiene esa pantalla específica, o el " +
                    "fabricante le puso otro nombre. Puedes buscarla manualmente " +
                    "abriendo \"Información de la app\" y revisando sus permisos."
            )
            .setPositiveButton("Abrir información de la app") { _, _ ->
                try {
                    startActivity(PermissionHelper.appDetailsSettingsIntent(this))
                } catch (_: Exception) {
                    Toast.makeText(this, "Tampoco está disponible en este dispositivo.", Toast.LENGTH_LONG).show()
                }
            }
            .setNegativeButton("Cerrar", null)
            .show()
    }

    private fun requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    android.Manifest.permission.BLUETOOTH_CONNECT,
                    android.Manifest.permission.BLUETOOTH_SCAN,
                    android.Manifest.permission.BLUETOOTH_ADVERTISE
                ),
                REQ_BT
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION),
                REQ_BT
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQ_NOTIF
            )
        }
    }

    private fun makeDiscoverable() {
        try {
            val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
            intent.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 300)
            startActivity(intent)
        } catch (_: Exception) {
            Toast.makeText(
                this,
                "Este dispositivo no soporta hacerse visible por Bluetooth. " +
                    "Empareja desde Ajustes de Bluetooth (paso 0) en su lugar.",
                Toast.LENGTH_LONG
            ).show()
        }
    }

}

