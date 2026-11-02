import 'package:flutter/material.dart';

import '../contracts/payment_result.dart';

/// Base berkomunikasi melalui kontrak; tidak mengetahui tipe dari modul.
abstract interface class FeatureModules {
  Future<void> loadPulsa();
  Widget pulsaPage(String storeId);
  Future<void> loadEdc();
  Future<EdcPaymentResult?> payWithEdc(
    BuildContext context, {
    required int amount,
    required String invoiceNumber,
  });
}
