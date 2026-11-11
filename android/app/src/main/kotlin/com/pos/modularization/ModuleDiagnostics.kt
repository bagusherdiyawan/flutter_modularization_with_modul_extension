package com.pos.modularization

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import java.util.zip.ZipFile

/** Local opt-in diagnostics. No network upload or transaction data collection. */
object ModuleDiagnostics {
    private var installed = false
    private fun prefs(context: Context) = context.applicationContext
        .getSharedPreferences("module_diagnostics", Context.MODE_PRIVATE)

    fun install(context: Context) {
        if (installed) return
        installed = true
        val storage = prefs(context)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                storage.edit().putString("javaCrash", error.stackTraceToString().take(16000))
                    .putLong("javaCrashTime", System.currentTimeMillis()).commit()
            } catch (_: Exception) { /* Preserve Android's original crash handling. */ }
            if (previous != null) previous.uncaughtException(thread, error)
            else Process.killProcess(Process.myPid())
        }
    }

    fun record(context: Context, module: String, stage: String) {
        require(module in setOf("edc", "pulsa"))
        require(stage in setOf("loading", "loaded", "failed"))
        // Commit before entering native loading, where a process abort can be immediate.
        prefs(context).edit().putString("module", module).putString("stage", stage)
            .putLong("time", System.currentTimeMillis()).commit()
    }

    @Suppress("DEPRECATION")
    fun report(context: Context): String = buildString {
        val storage = prefs(context)
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val app = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        appendLine("SmartPOS module diagnostics v2")
        appendLine("adapter=feature-delivery-2.1-gms-v1")
        appendLine("package=${context.packageName}")
        appendLine("version=${info.versionName}; code=${if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()}")
        appendLine("device=${Build.MANUFACTURER} ${Build.MODEL}; API=${Build.VERSION.SDK_INT}")
        appendLine("ABI=${Build.SUPPORTED_ABIS.joinToString()}")
        appendLine("lastModule=${storage.getString("module", "none")}")
        appendLine("lastStage=${storage.getString("stage", "none")}; time=${storage.getLong("time", 0)}")
        appendLine("mapping=${app.metaData?.getString("io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping")}")
        appendLine("installedSplits=${info.splitNames?.joinToString() ?: "none"}")
        for (path in app.splitSourceDirs.orEmpty()) {
            appendLine("split=${java.io.File(path).name}")
            try {
                ZipFile(path).use { zip ->
                    val entries = zip.entries()
                    while (entries.hasMoreElements()) {
                        val name = entries.nextElement().name
                        if (name.startsWith("lib/") && name.endsWith(".part.so")) appendLine("  $name")
                    }
                }
            } catch (error: Exception) { appendLine("splitReadError=${error.javaClass.simpleName}") }
        }
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                for (exit in manager.getHistoricalProcessExitReasons(context.packageName, 0, 3)) {
                    appendLine("exit: time=${exit.timestamp}; reason=${exit.reason}; status=${exit.status}; description=${exit.description}")
                }
            } catch (error: Exception) { appendLine("exitHistoryError=${error.javaClass.simpleName}") }
        }
        appendLine("lastJavaCrashTime=${storage.getLong("javaCrashTime", 0)}")
        appendLine(storage.getString("javaCrash", "No Java stack recorded. Native crashes require Android logcat."))
    }
}
