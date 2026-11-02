/// Kontrak netral; implementasi SDK EDC tetap berada di modul on-demand.
class EdcPaymentResult {
  const EdcPaymentResult({
    required this.isSuccess,
    this.approvalCode = '',
    this.cardNumberMasked = '',
    this.errorMessage = '',
    this.isSimulation = false,
  });

  final bool isSuccess;
  final String approvalCode;
  final String cardNumberMasked;
  final String errorMessage;
  final bool isSimulation;
}
