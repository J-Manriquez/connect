package com.example.connect

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class FloatingBallAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        private var instance: FloatingBallAccessibilityService? = null

        fun performGlobalActionSafe(action: Int): Boolean {
            val svc = instance ?: return false
            return try {
                svc.performGlobalAction(action)
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    }

    override fun onInterrupt() {
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
