import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pos/core/services/module_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ModuleDiagnostics.channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ModuleDiagnostics.channel, null);
  });
  test(
    'records a loading checkpoint before invoking native module loading',
    () async {
      await ModuleDiagnostics.track('edc', () async {
        expect(calls.single.arguments['stage'], 'loading');
      });
      expect(calls.map((c) => c.arguments['stage']), ['loading', 'loaded']);
    },
  );
  test('keeps the original loading error and records failure', () async {
    final original = StateError('module failed');
    await expectLater(
      ModuleDiagnostics.track('edc', () async => throw original),
      throwsA(same(original)),
    );
    expect(calls.map((c) => c.arguments['stage']), ['loading', 'failed']);
  });
  test('diagnostic failure does not prevent loading', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ModuleDiagnostics.channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    var loaded = false;
    await ModuleDiagnostics.track('pulsa', () async {
      loaded = true;
    });
    expect(loaded, isTrue);
  });
}
