import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/contracts/payment_result.dart';
import 'package:smart_pos/core/services/deferred_feature_modules.dart';
import 'package:smart_pos/features/edc_module/edc_service.dart';
import 'package:smart_pos/features/edc_module/edc_entry.dart';
import 'package:smart_pos/features/pulsa_module/pulsa_entry.dart';

void main() {
  test('EDC simulator membedakan demo dari approval nyata', () async {
    final service = EdcService(delay: Duration.zero);
    final result = await service.pay(amount: 150000, invoiceNumber: 'INV-TEST');
    expect(result.isSuccess, isTrue);
    expect(result.isSimulation, isTrue);
    expect(result.cardNumberMasked, contains('XXXX'));
    final invalid = await service.pay(amount: 0, invoiceNumber: 'INV-TEST');
    expect(invalid.isSuccess, isFalse);
  });

  testWidgets('Gateway deferred dapat membuka Pulsa setelah loadLibrary', (
    tester,
  ) async {
    const modules = DeferredFeatureModules();
    await tester.runAsync(modules.loadPulsa);
    await tester.pumpWidget(MaterialApp(home: modules.pulsaPage('STORE-TEST')));
    await tester.pumpAndSettle();
    expect(find.text('ID Toko Aktif: STORE-TEST'), findsOneWidget);
  });

  testWidgets('Pulsa memvalidasi nomor dan pilihan produk berubah', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PulsaEntryPoint(storeId: 'TEST')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-pulsa')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Masukkan nomor HP'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('customer-number')),
      '081234567890',
    );
    await tester.tap(find.text('Pulsa Rp 25.000'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy-pulsa')));
    await tester.pumpAndSettle();
    expect(find.text('Simulasi pesanan'), findsOneWidget);
    expect(
      find.textContaining('Pulsa Rp 25.000\nTujuan: 081234567890'),
      findsOneWidget,
    );
  });

  testWidgets('PLN menerima ID meter, menolak nomor terlalu pendek', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PulsaEntryPoint(storeId: 'TEST')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Token PLN Rp 20.000'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-number')), '123');
    await tester.tap(find.byKey(const Key('buy-pulsa')));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan 11–12 digit nomor PLN.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('customer-number')),
      '12345678901',
    );
    await tester.tap(find.byKey(const Key('buy-pulsa')));
    await tester.pumpAndSettle();
    expect(find.text('Simulasi pesanan'), findsOneWidget);
  });

  testWidgets('EDC dapat dibatalkan tanpa hasil sukses setelah timer selesai', (
    tester,
  ) async {
    EdcPaymentResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await EdcEntryPoint.processEdcPayment(
                  context,
                  amount: 150000,
                  invoiceNumber: 'TEST',
                );
              },
              child: const Text('Mulai'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mulai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(result?.isSuccess, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(result?.errorMessage, 'Dibatalkan oleh kasir');
    expect(tester.takeException(), isNull);
  });
}
