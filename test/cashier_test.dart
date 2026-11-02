import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/contracts/payment_result.dart';
import 'package:smart_pos/core/services/feature_modules.dart';
import 'package:smart_pos/core/services/store_config_service.dart';
import 'package:smart_pos/main.dart';

class FakeModules implements FeatureModules {
  int pulsaLoads = 0;
  int edcLoads = 0;
  Completer<void>? pendingLoad;
  bool fail = false;
  EdcPaymentResult? result = const EdcPaymentResult(
    isSuccess: true,
    approvalCode: 'TEST-123',
    cardNumberMasked: 'XXXX-1234',
    isSimulation: true,
  );

  @override
  Future<void> loadPulsa() async {
    pulsaLoads++;
    if (fail) throw StateError('Offline');
    await pendingLoad?.future;
  }

  @override
  Future<void> loadEdc() async {
    edcLoads++;
    if (fail) throw StateError('Offline');
    await pendingLoad?.future;
  }

  @override
  Widget pulsaPage(String storeId) => Scaffold(body: Text('Pulsa $storeId'));

  @override
  Future<EdcPaymentResult?> payWithEdc(
    BuildContext context, {
    required int amount,
    required String invoiceNumber,
  }) async {
    expect(amount, 150000);
    expect(invoiceNumber, startsWith('INV-'));
    return result;
  }
}

void main() {
  testWidgets('Toko reguler tidak memuat modul; tunai selalu tersedia', (
    tester,
  ) async {
    final modules = FakeModules();
    await tester.pumpWidget(SmartPosApp(modules: modules));
    expect(find.byKey(const Key('open-pulsa')), findsNothing);
    expect(find.byKey(const Key('edc-payment')), findsNothing);
    await tester.tap(find.byKey(const Key('cash-payment')));
    await tester.pumpAndSettle();
    expect(find.text('Struk demo'), findsOneWidget);
    expect(modules.pulsaLoads + modules.edcLoads, 0);
  });

  testWidgets('Aktivasi fitur tidak mengunduh; klik baru memuat Pulsa', (
    tester,
  ) async {
    final modules = FakeModules();
    await tester.pumpWidget(SmartPosApp(modules: modules));
    await tester.tap(find.byKey(const Key('enable-pulsa')));
    await tester.pumpAndSettle();
    expect(modules.pulsaLoads, 0);
    await tester.ensureVisible(find.byKey(const Key('open-pulsa')));
    await tester.tap(find.byKey(const Key('open-pulsa')));
    await tester.pumpAndSettle();
    expect(modules.pulsaLoads, 1);
    expect(find.text('Pulsa STORE-JOGJA-01'), findsOneWidget);
  });

  testWidgets(
    'Loading mencegah klik ganda lalu hilang setelah gagal; dapat retry',
    (tester) async {
      final modules = FakeModules()..pendingLoad = Completer<void>();
      final config = StoreConfigService(usesEdc: true);
      await tester.pumpWidget(
        SmartPosApp(modules: modules, storeConfig: config),
      );
      await tester.tap(find.byKey(const Key('edc-payment')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(modules.edcLoads, 1);
      modules.pendingLoad!.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Modul EDC gagal'), findsOneWidget);
      modules.pendingLoad = null;
      await tester.tap(find.byKey(const Key('edc-payment')));
      await tester.pumpAndSettle();
      expect(modules.edcLoads, 2);
      expect(find.textContaining('TEST-123'), findsOneWidget);
    },
  );

  testWidgets(
    'Pulsa gagal dimuat tidak membuka halaman dan dapat dicoba lagi',
    (tester) async {
      final modules = FakeModules()..fail = true;
      await tester.pumpWidget(
        SmartPosApp(
          modules: modules,
          storeConfig: StoreConfigService(usesPulsa: true),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('open-pulsa')));
      await tester.tap(find.byKey(const Key('open-pulsa')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Modul Pulsa gagal'), findsOneWidget);
      expect(find.text('Pulsa STORE-JOGJA-01'), findsNothing);
      modules.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-pulsa')));
      await tester.pumpAndSettle();
      expect(modules.pulsaLoads, 2);
      expect(find.text('Pulsa STORE-JOGJA-01'), findsOneWidget);
    },
  );

  testWidgets('Hasil pembatalan EDC tidak menjadi struk sukses', (
    tester,
  ) async {
    final modules = FakeModules()
      ..result = const EdcPaymentResult(
        isSuccess: false,
        errorMessage: 'Dibatalkan oleh kasir',
      );
    await tester.pumpWidget(
      SmartPosApp(
        modules: modules,
        storeConfig: StoreConfigService(usesEdc: true),
      ),
    );
    await tester.tap(find.byKey(const Key('edc-payment')));
    await tester.pumpAndSettle();
    expect(find.text('Dibatalkan oleh kasir'), findsOneWidget);
    expect(find.text('Struk demo'), findsNothing);
  });

  testWidgets('Penyelesaian download setelah halaman disposed aman', (
    tester,
  ) async {
    final modules = FakeModules()..pendingLoad = Completer<void>();
    await tester.pumpWidget(
      SmartPosApp(
        modules: modules,
        storeConfig: StoreConfigService(usesEdc: true),
      ),
    );
    await tester.tap(find.byKey(const Key('edc-payment')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    modules.pendingLoad!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
