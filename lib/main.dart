import 'package:flutter/material.dart';

import 'core/services/deferred_feature_modules.dart';
import 'core/services/feature_modules.dart';
import 'core/services/store_config_service.dart';
import 'features/pos_cashier/cashier_page.dart';

void main() => runApp(const SmartPosApp());

class SmartPosApp extends StatelessWidget {
  const SmartPosApp({super.key, this.modules, this.storeConfig});

  final FeatureModules? modules;
  final StoreConfigService? storeConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245A81)),
        useMaterial3: true,
      ),
      home: CashierPage(
        modules: modules ?? const DeferredFeatureModules(),
        storeConfig: storeConfig ?? StoreConfigService(),
      ),
    );
  }
}
