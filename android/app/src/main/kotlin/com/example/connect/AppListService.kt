package com.example.connect

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream

class AppListService(private val context: Context) {
    
    companion object {
        private const val TAG = "AppListService"
    }
    
    // Obtener todas las aplicaciones instaladas
    fun getInstalledApps(): List<Map<String, Any>> {
        val packageManager = context.packageManager
        val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        
        return installedApps.map { appInfo ->
            val appName = packageManager.getApplicationLabel(appInfo).toString()
            val packageName = appInfo.packageName
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            
            // Convertir el icono a Base64 para enviarlo a Flutter
            val iconDrawable = packageManager.getApplicationIcon(appInfo)
            val iconBase64 = drawableToBase64(iconDrawable)
            
            mapOf(
                "appName" to appName,
                "packageName" to packageName,
                "isSystemApp" to isSystemApp,
                "icon" to iconBase64
            )
        }.sortedBy { it["appName"] as String }
    }
    
    // Convertir un Drawable a una cadena Base64
    private fun drawableToBase64(drawable: Drawable): String {
        try {
            // Limitar el tamaño del icono para evitar problemas de memoria
            val maxSize = 96
            val width = Math.min(drawable.intrinsicWidth, maxSize)
            val height = Math.min(drawable.intrinsicHeight, maxSize)
            
            val bitmap = Bitmap.createBitmap(
                width,
                height,
                Bitmap.Config.ARGB_8888
            )
            
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            
            val byteArrayOutputStream = ByteArrayOutputStream()
            // Usar una compresión menor para reducir el tamaño
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            
            // Asegurar que no haya saltos de línea en la cadena Base64
            return Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.e(TAG, "Error al convertir drawable a base64", e)
            return ""
        }
    }
}