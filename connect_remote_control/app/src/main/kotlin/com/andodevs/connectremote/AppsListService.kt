package com.andodevs.connectremote

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * Lista las apps con ícono de lanzador instaladas en el receptor, para que
 * el emisor pueda ofrecer accesos rápidos (p. ej. abrir YouTube) desde el
 * modo D-pad. Usa `<queries>` (manifest) en vez de QUERY_ALL_PACKAGES, que es
 * el mecanismo moderno recomendado desde Android 11 para listar apps
 * lanzables sin permisos especiales.
 */
object AppsListService {
    data class AppEntry(val packageName: String, val label: String)

    fun getLaunchableApps(context: Context): List<AppEntry> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = try {
            pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        } catch (_: Exception) {
            emptyList()
        }
        return resolved
            .mapNotNull { info ->
                try {
                    val pkg = info.activityInfo.packageName
                    val label = info.loadLabel(pm).toString()
                    if (pkg.isNullOrBlank() || label.isBlank()) null else AppEntry(pkg, label)
                } catch (_: Exception) {
                    null
                }
            }
            .distinctBy { it.packageName }
            .filter { it.packageName != context.packageName }
            .sortedBy { it.label.lowercase() }
    }

    fun launch(context: Context, packageName: String): Boolean {
        return try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
