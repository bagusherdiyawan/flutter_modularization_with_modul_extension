import '../../core/contracts/payment_result.dart';

/// Simulator terisolasi. Ganti dengan adapter SDK vendor di modul ini.
/// Jangan kembalikan approval simulasi pada transaksi produksi.
class EdcService {
  const EdcService({this.delay = const Duration(seconds: 3)});

  final Duration delay;

  Future<EdcPaymentResult> pay({
    required int amount,
    required String invoiceNumber,
  }) async {
    if (amount <= 0 || invoiceNumber.isEmpty) {
      return const EdcPaymentResult(
        isSuccess: false,
        errorMessage: 'Transaksi tidak valid.',
      );
    }
    await Future<void>.delayed(delay);
    return const EdcPaymentResult(
      isSuccess: true,
      approvalCode: 'DEMO-992817',
      cardNumberMasked: '4111-XXXX-XXXX-1234',
      isSimulation: true,
    );
  }
}
