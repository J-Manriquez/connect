package com.andodevs.connectremote

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    companion object {
        const val PREFS_NAME = "connect_remote_prefs"
        const val KEY_SERVICE_ENABLED = "service_enabled"
    }

    private lateinit var tvStatus: TextView
    private lateinit var tvPermissionsStatus: TextView
    private lateinit var btnToggleService: Button
    private val refreshHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvStatus = findViewById(R.id.tvStatus)
        tvPermissionsStatus = findViewById(R.id.tvPermissionsStatus)
        btnToggleService = findViewById(R.id.btnToggleService)

        btnToggleService.setOnClickListener {
            if (RemoteServerService.isRunning) {
                stopService()
            } else {
                startService()
            }
        }

        findViewById<Button>(R.id.btnPermissions).setOnClickListener {
            startActivity(Intent(this, OnboardingActivity::class.java))
        }
        findViewById<Button>(R.id.btnGoHome).setOnClickListener {
            startActivity(
                Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            )
        }
    }

    override fun onResume() {
        super.onResume()
        refreshUi()
        refreshHandler.postDelayed(refreshRunnable, 1000L)
    }

    override fun onPause() {
        refreshHandler.removeCallbacks(refreshRunnable)
        super.onPause()
    }

    private val refreshRunnable = object : Runnable {
        override fun run() {
            refreshUi()
            refreshHandler.postDelayed(this, 1000L)
        }
    }

    private fun refreshUi() {
        val running = RemoteServerService.isRunning
        tvStatus.text = if (running) {
            val peer = RemoteServerService.connectedPeerName
            if (peer != null) "Conectado a: $peer" else "Receptor activo, esperando conexión"
        } else {
            "Receptor detenido"
        }
        btnToggleService.text = if (running) "Detener receptor" else "Activar receptor"

        val ready = PermissionHelper.allCoreReady(this)
        tvPermissionsStatus.text = if (ready) {
            "Permisos listos ✓"
        } else {
            "Faltan permisos — toca \"Configurar permisos\""
        }
    }

    private fun startService() {
        if (!PermissionHelper.allCoreReady(this)) {
            startActivity(Intent(this, OnboardingActivity::class.java))
            return
        }
        val intent = Intent(this, RemoteServerService::class.java)
            .setAction(RemoteServerService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putBoolean(KEY_SERVICE_ENABLED, true)
            .apply()
        refreshUi()
    }

    private fun stopService() {
        val intent = Intent(this, RemoteServerService::class.java)
            .setAction(RemoteServerService.ACTION_STOP)
        startService(intent)
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putBoolean(KEY_SERVICE_ENABLED, false)
            .apply()
        refreshUi()
    }
}
