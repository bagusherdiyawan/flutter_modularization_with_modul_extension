package com.pos.modularization

import com.google.android.play.core.splitcompat.SplitCompatApplication
import io.flutter.FlutterInjector

/** Use a source-compiled adapter compatible with Play Feature Delivery 2.1.0. */
class SmartPosApplication : SplitCompatApplication() {
    override fun onCreate() {
        super.onCreate()
        ModuleDiagnostics.install(this)
        FlutterInjector.setInstance(
            FlutterInjector.Builder()
                .setDeferredComponentManager(SmartPosDeferredComponentManager(this, null))
                .build()
        )
    }
}
