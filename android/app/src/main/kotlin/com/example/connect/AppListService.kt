package com.example.connect

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppListService(private val context: Context) {
    
    companion object {
        private const val TAG = "AppListService"
        private const val PREFS_NAME = "AppListPrefs"
        private const val KEY_APP_LIST = "app_list"
        private const val KEY_LAST_UPDATE = "last_update"
        private const val KEY_STATUS = "status_list_apps"
        private const val KEY_ENABLED_PACKAGES = "enabled_packages"
    }
    
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // Obtener todas las aplicaciones instaladas
    fun getInstalledApps(): List<Map<String, Any>> {
        // Primero intentamos cargar desde SharedPreferences
        val cachedApps = loadAppsFromPrefs()
        if (cachedApps.isNotEmpty()) {
            Log.d(TAG, "Cargando ${cachedApps.size} aplicaciones desde SharedPreferences")
            return cachedApps
        }
        
        // Si no hay datos en SharedPreferences, cargamos del sistema
        Log.d(TAG, "No hay datos en SharedPreferences, cargando desde el sistema")
        return loadAppsFromSystem()
    }
    
    // Cargar aplicaciones desde el sistema
    fun loadAppsFromSystem(): List<Map<String, Any>> {
        val packageManager = context.packageManager
        val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        
        // Cargar los paquetes habilitados existentes
        val enabledPackages = getEnabledPackages()
        
        val appsList = installedApps.map { appInfo ->
            val appName = packageManager.getApplicationLabel(appInfo).toString()
            val packageName = appInfo.packageName
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            
            // Convertir el icono a Base64 para enviarlo a Flutter
            val iconDrawable = packageManager.getApplicationIcon(appInfo)
            val iconBase64 = drawableToBase64(iconDrawable)
            
            // Verificar si la aplicación estaba habilitada previamente
            val isEnabled = enabledPackages.contains(packageName)
            
            mapOf(
                "appName" to appName,
                "packageName" to packageName,
                "isSystemApp" to isSystemApp,
                "icon" to iconBase64,
                "isEnabled" to isEnabled
            )
        }.sortedBy { it["appName"] as String }
        
        // Guardar en SharedPreferences
        saveAppsToPrefs(appsList)
        
        return appsList
    }
    
    // Guardar la lista de aplicaciones en SharedPreferences
    private fun saveAppsToPrefs(apps: List<Map<String, Any>>) {
        try {
            val jsonArray = JSONArray()
            
            for (app in apps) {
                val jsonObject = JSONObject()
                jsonObject.put("appName", app["appName"])
                jsonObject.put("packageName", app["packageName"])
                jsonObject.put("isSystemApp", app["isSystemApp"])
                jsonObject.put("icon", app["icon"])
                jsonObject.put("isEnabled", app["isEnabled"])
                jsonArray.put(jsonObject)
            }
            
            val editor = sharedPreferences.edit()
            editor.putString(KEY_APP_LIST, jsonArray.toString())
            
            // Guardar la fecha de actualización
            val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
            val currentDate = dateFormat.format(Date())
            editor.putString(KEY_LAST_UPDATE, currentDate)
            
            // Establecer el estado como activo
            editor.putString(KEY_STATUS, "activo")
            
            // Guardar también la lista de paquetes habilitados
            val enabledPackages = apps
                .filter { it["isEnabled"] as Boolean }
                .map { it["packageName"] as String }
            
            editor.putStringSet(KEY_ENABLED_PACKAGES, enabledPackages.toSet())
            
            editor.apply()
            
            Log.d(TAG, "Guardadas ${apps.size} aplicaciones en SharedPreferences")
            Log.d(TAG, "Aplicaciones habilitadas: ${enabledPackages.size}")
            
            // Notificar a Flutter para sincronizar con Firebase
            MainActivity.instance?.let { activity ->
                if (activity is MainActivity) {
                    activity.notifyAppListUpdated()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al guardar aplicaciones en SharedPreferences", e)
        }
    }
    
    // Cargar la lista de aplicaciones desde SharedPreferences
    private fun loadAppsFromPrefs(): List<Map<String, Any>> {
        try {
            val status = sharedPreferences.getString(KEY_STATUS, null)
            if (status != "activo") {
                Log.d(TAG, "Estado no activo en SharedPreferences")
                return emptyList()
            }
            
            val jsonString = sharedPreferences.getString(KEY_APP_LIST, null) ?: return emptyList()
            val jsonArray = JSONArray(jsonString)
            val appsList = mutableListOf<Map<String, Any>>()
            
            for (i in 0 until jsonArray.length()) {
                val jsonObject = jsonArray.getJSONObject(i)
                val app = mapOf(
                    "appName" to jsonObject.getString("appName"),
                    "packageName" to jsonObject.getString("packageName"),
                    "isSystemApp" to jsonObject.getBoolean("isSystemApp"),
                    "icon" to jsonObject.getString("icon"),
                    "isEnabled" to jsonObject.optBoolean("isEnabled", false)
                )
                appsList.add(app)
            }
            
            Log.d(TAG, "Cargadas ${appsList.size} aplicaciones desde SharedPreferences")
            return appsList
        } catch (e: Exception) {
            Log.e(TAG, "Error al cargar aplicaciones desde SharedPreferences", e)
            return emptyList()
        }
    }
    
    // Obtener la fecha de la última actualización
    fun getLastUpdateDate(): String {
        return sharedPreferences.getString(KEY_LAST_UPDATE, "Nunca") ?: "Nunca"
    }
    
    // Obtener la lista de paquetes habilitados
    fun getEnabledPackages(): Set<String> {
        return sharedPreferences.getStringSet(KEY_ENABLED_PACKAGES, emptySet()) ?: emptySet()
    }
    
    // Actualizar el estado de una aplicación
    fun updateAppState(packageName: String, isEnabled: Boolean) {
        try {
            // Cargar las aplicaciones actuales
            val apps = loadAppsFromPrefs().toMutableList()
            
            // Buscar la aplicación por su packageName y actualizar su estado
            val updatedApps = apps.map { app ->
                if (app["packageName"] == packageName) {
                    // Crear una copia del mapa con el estado actualizado
                    app.toMutableMap().apply { 
                        this["isEnabled"] = isEnabled 
                    }
                } else {
                    app
                }
            }
            
            // Guardar la lista actualizada
            saveAppsToPrefs(updatedApps)
            
            Log.d(TAG, "Estado de la aplicación $packageName actualizado a $isEnabled")
        } catch (e: Exception) {
            Log.e(TAG, "Error al actualizar el estado de la aplicación", e)
        }
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