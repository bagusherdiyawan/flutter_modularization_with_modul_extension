import 'package:flutter/services.dart';

/// Best-effort local checkpoints; never hide the actual module-loading error.
class ModuleDiagnostics {
  static const channel = MethodChannel('smartpos/module_diagnostics');

  static Future<void> _record(String module, String stage) async {
    try {
      await channel.invokeMethod<void>('record', {
        'module': module,
        'stage': stage,
      });
    } catch (_) {
      // Missing diagnostics must not prevent loading or replace its error.
    }
  }

  static Future<void> track(String module, Future<void> Function() load) async {
    await _record(module, 'loading');
    try {
      await load();
      await _record(module, 'loaded');
    } catch (_) {
      await _record(module, 'failed');
      rethrow;
    }
  }

  static Future<String> report() async {
    try {
      return await channel.invokeMethod<String>('report') ??
          'Diagnosis Android belum tersedia.';
    } catch (_) {
      return 'Diagnosis Android tidak tersedia pada build/perangkat ini.';
    }
  }
}
