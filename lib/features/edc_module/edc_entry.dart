import 'package:flutter/material.dart';

import '../../core/contracts/payment_result.dart';
import 'edc_payment_dialog.dart';

class EdcEntryPoint {
  static Future<EdcPaymentResult?> processEdcPayment(
    BuildContext context, {
    required int amount,
    required String invoiceNumber,
  }) {
    if (amount <= 0 || invoiceNumber.isEmpty) {
      return Future.value(
        const EdcPaymentResult(
          isSuccess: false,
          errorMessage: 'Nominal atau invoice tidak valid.',
        ),
      );
    }
    return showDialog<EdcPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EdcPaymentDialog(amount: amount, invoiceNumber: invoiceNumber),
    );
  }
}
