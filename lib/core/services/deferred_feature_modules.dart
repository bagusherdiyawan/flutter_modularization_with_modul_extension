import 'package:flutter/material.dart';

import '../../features/edc_module/edc_entry.dart' deferred as edc;
import '../../features/pulsa_module/pulsa_entry.dart' deferred as pulsa;
import '../contracts/payment_result.dart';
import 'feature_modules.dart';
import 'module_diagnostics.dart';

class DeferredFeatureModules implements FeatureModules {
  const DeferredFeatureModules();

  @override
  Future<void> loadPulsa() =>
      ModuleDiagnostics.track('pulsa', pulsa.loadLibrary);

  @override
  Widget pulsaPage(String storeId) => pulsa.PulsaEntryPoint(storeId: storeId);

  @override
  Future<void> loadEdc() => ModuleDiagnostics.track('edc', edc.loadLibrary);

  @override
  Future<EdcPaymentResult?> payWithEdc(
    BuildContext context, {
    required int amount,
    required String invoiceNumber,
  }) => edc.EdcEntryPoint.processEdcPayment(
    context,
    amount: amount,
    invoiceNumber: invoiceNumber,
  );
}
