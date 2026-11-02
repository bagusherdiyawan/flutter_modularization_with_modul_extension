import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/contracts/payment_result.dart';
import 'edc_service.dart';

class EdcPaymentDialog extends StatefulWidget {
  const EdcPaymentDialog({
    super.key,
    required this.amount,
    required this.invoiceNumber,
  });

  final int amount;
  final String invoiceNumber;

  @override
  State<EdcPaymentDialog> createState() => _EdcPaymentDialogState();
}

class _EdcPaymentDialogState extends State<EdcPaymentDialog> {
  late final Future<String> _instructions = rootBundle.loadString(
    'assets/edc_assets/instructions.txt',
  );

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final result = await const EdcService().pay(
      amount: widget.amount,
      invoiceNumber: widget.invoiceNumber,
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('Simulasi mesin EDC'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Nominal: Rp ${widget.amount}\nInvoice: ${widget.invoiceNumber}',
          ),
          FutureBuilder<String>(
            future: _instructions,
            builder: (_, snapshot) =>
                Text(snapshot.data ?? 'Menyiapkan simulator EDC...'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const EdcPaymentResult(
              isSuccess: false,
              errorMessage: 'Dibatalkan oleh kasir',
              isSimulation: true,
            ),
          ),
          child: const Text('Batalkan'),
        ),
      ],
    ),
  );
}
