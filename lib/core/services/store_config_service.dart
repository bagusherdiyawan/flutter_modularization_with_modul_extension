import 'package:flutter/foundation.dart';

/// Konfigurasi demo dalam memori. Produksi harus membaca entitlement backend.
/// Sakelar lokal bukan mekanisme otorisasi transaksi.
class StoreConfigService extends ChangeNotifier {
  StoreConfigService({
    this.storeId = 'STORE-JOGJA-01',
    bool usesPulsa = false,
    bool usesEdc = false,
  }) : _usesPulsa = usesPulsa,
       _usesEdc = usesEdc;

  final String storeId;
  bool _usesPulsa;
  bool _usesEdc;

  bool get usesPulsa => _usesPulsa;
  bool get usesEdc => _usesEdc;

  void setUsesPulsa(bool value) {
    _usesPulsa = value;
    notifyListeners();
  }

  void setUsesEdc(bool value) {
    _usesEdc = value;
    notifyListeners();
  }
}
