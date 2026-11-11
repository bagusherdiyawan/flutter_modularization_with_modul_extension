package com.pos.modularization

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ModuleDiagnostics.install(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartpos/module_diagnostics")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "record" -> {
                            ModuleDiagnostics.record(applicationContext,
                                call.argument<String>("module") ?: "",
                                call.argument<String>("stage") ?: "")
                            result.success(null)
                        }
                        "report" -> result.success(ModuleDiagnostics.report(applicationContext))
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("diagnostics_failed", error.javaClass.simpleName, null)
                }
            }
    }
}
