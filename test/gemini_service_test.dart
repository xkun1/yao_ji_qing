import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = GeminiService();

  setUp(() {
    service.resetTestingOverrides();
    service.resetInitializationState();
  });

  tearDown(() {
    service.resetTestingOverrides();
    service.resetInitializationState();
  });

  test('ensureInitialized clears cached failure so next call can retry',
      () async {
    var attempts = 0;
    GeminiService.initializationRunner = () async {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('init failed');
      }
    };

    await expectLater(service.ensureInitialized(), throwsA(isA<StateError>()));
    await service.ensureInitialized();

    expect(attempts, 2);
  });

  test('ensureInitialized reuses in-flight successful initialization',
      () async {
    final completer = Completer<void>();
    var attempts = 0;
    GeminiService.initializationRunner = () {
      attempts += 1;
      return completer.future;
    };

    final first = service.ensureInitialized();
    final second = service.ensureInitialized();
    completer.complete();

    await Future.wait([first, second]);
    expect(attempts, 1);
  });

  test(
      'isModelReady is false when only local file is detected but not installed',
      () async {
    GeminiService.initializationRunner = () async {};
    GeminiService.modelInstalledChecker = (_) async => false;
    GeminiService.existingModelPathFinderOverride =
        () async => '/tmp/mock-model';

    expect(await service.isModelReady(), isFalse);
  });
}
