import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PulsaDashboardPage extends StatefulWidget {
  const PulsaDashboardPage({super.key, required this.storeId});

  final String storeId;

  @override
  State<PulsaDashboardPage> createState() => _PulsaDashboardPageState();
}

class _PulsaDashboardPageState extends State<PulsaDashboardPage> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  static const _products = [
    'Pulsa Rp 10.000',
    'Pulsa Rp 25.000',
    'Pulsa Rp 50.000',
    'Token PLN Rp 20.000',
  ];
  late final Future<String> _notice = rootBundle.loadString(
    'assets/pulsa_assets/notice.txt',
  );
  int _selected = 0;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pulsa & PPOB')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ID Toko Aktif: ${widget.storeId}'),
          FutureBuilder<String>(
            future: _notice,
            builder: (_, snapshot) => Text(
              snapshot.data ?? 'Demo produk digital — tanpa transaksi nyata.',
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('customer-number'),
            controller: _number,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _selected == 3
                  ? 'Nomor meter / ID pelanggan PLN'
                  : 'Nomor HP pelanggan',
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final text = value ?? '';
              if (_selected == 3) {
                return RegExp(r'^\d{11,12}$').hasMatch(text)
                    ? null
                    : 'Masukkan 11–12 digit nomor PLN.';
              }
              return RegExp(r'^08\d{8,11}$').hasMatch(text)
                  ? null
                  : 'Masukkan nomor HP 10–13 digit, diawali 08.';
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _products.length; index++)
                ChoiceChip(
                  label: Text(_products[index]),
                  selected: _selected == index,
                  onSelected: (_) => setState(() => _selected = index),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            key: const Key('buy-pulsa'),
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Simulasi pesanan'),
                  content: Text(
                    '${_products[_selected]}\nTujuan: ${_number.text}\nBelum dikirim ke provider. Tidak ada saldo terpotong.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Simulasikan pembelian'),
          ),
        ],
      ),
    ),
  );
}
