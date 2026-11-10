import 'package:flutter/material.dart';

import '../../core/services/feature_modules.dart';
import '../../core/services/store_config_service.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({
    super.key,
    required this.modules,
    required this.storeConfig,
  });

  final FeatureModules modules;
  final StoreConfigService storeConfig;

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  static const _total = 150000;
  bool _busy = false;
  String _message = '';
  int _invoiceSequence = 0;
  bool _pulsaReady = false;
  bool _edcReady = false;

  Future<bool> _confirmDownload(String feature, bool ready) async {
    if (ready) return true;
    setState(() => _busy = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Unduh fitur $feature?"),
        content: const Text(
          "Aplikasi akan meminta Google Play memasang modul jika belum tersedia. Koneksi internet mungkin diperlukan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Batal"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Unduh"),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    setState(() => _busy = false);
    return accepted == true;
  }

  String _newInvoice() =>
      'INV-${DateTime.now().microsecondsSinceEpoch}-${++_invoiceSequence}';

  Future<void> _openPulsa() async {
    if (_busy || !widget.storeConfig.usesPulsa) return;
    if (!await _confirmDownload("Pulsa / PPOB", _pulsaReady) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = 'Menyiapkan modul Pulsa & PPOB...';
    });
    try {
      await widget.modules.loadPulsa();
      _pulsaReady = true;
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => widget.modules.pulsaPage(widget.storeConfig.storeId),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showError('Modul Pulsa gagal dimuat. Periksa koneksi lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payEdc() async {
    if (_busy || !widget.storeConfig.usesEdc) return;
    if (!await _confirmDownload("EDC", _edcReady) || !mounted) return;
    setState(() {
      _busy = true;
      _message = 'Menyiapkan modul Mesin EDC...';
    });
    try {
      await widget.modules.loadEdc();
      _edcReady = true;
      if (!mounted) return;
      setState(() => _message = 'Menunggu transaksi EDC selesai...');
      final result = await widget.modules.payWithEdc(
        context,
        amount: _total,
        invoiceNumber: _newInvoice(),
      );
      if (!mounted || result == null) return;
      setState(() => _busy = false);
      if (result.isSuccess) {
        await _showReceipt(
          '${result.isSimulation ? 'SIMULASI — ' : ''}Pembayaran EDC berhasil.\n'
          'Total: Rp 150.000\nApproval: ${result.approvalCode}\n'
          'Kartu: ${result.cardNumberMasked}',
        );
      } else {
        _showError(result.errorMessage);
      }
    } catch (_) {
      if (mounted) {
        _showError('Modul EDC gagal dimuat. Periksa koneksi lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
  );

  Future<void> _showReceipt(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Struk demo'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.storeConfig,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('SmartPOS Kasir Utama')),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.storeConfig.storeId),
                const Text('Demo transaksi — tidak memindahkan dana.'),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      const ListTile(title: Text('Konfigurasi fitur toko')),
                      SwitchListTile(
                        key: const Key('enable-pulsa'),
                        title: const Text('Aktifkan Pulsa / PPOB'),
                        value: widget.storeConfig.usesPulsa,
                        onChanged: _busy
                            ? null
                            : widget.storeConfig.setUsesPulsa,
                      ),
                      SwitchListTile(
                        key: const Key('enable-edc'),
                        title: const Text('Toko memiliki mesin EDC'),
                        value: widget.storeConfig.usesEdc,
                        onChanged: _busy ? null : widget.storeConfig.setUsesEdc,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Keranjang contoh', style: TextStyle(fontSize: 20)),
                const ListTile(
                  title: Text('3 × Barang @ Rp 50.000'),
                  trailing: Text('Rp 150.000'),
                ),
                const Text(
                  'Total: Rp 150.000',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('cash-payment'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Bayar tunai (demo)'),
                  onPressed: _busy
                      ? null
                      : () => _showReceipt(
                          'Pembayaran tunai demo Rp 150.000.\nInvoice: ${_newInvoice()}',
                        ),
                ),
                if (widget.storeConfig.usesEdc)
                  FilledButton.tonalIcon(
                    key: const Key('edc-payment'),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Bayar via EDC (simulasi)'),
                    onPressed: _busy ? null : _payEdc,
                  ),
                const Divider(height: 32),
                if (widget.storeConfig.usesPulsa)
                  OutlinedButton.icon(
                    key: const Key('open-pulsa'),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Pulsa & Token PLN'),
                    onPressed: _busy ? null : _openPulsa,
                  ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_message),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
