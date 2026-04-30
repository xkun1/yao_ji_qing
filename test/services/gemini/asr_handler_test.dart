import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini/asr_handler.dart';

void main() {
  group('AsrHandler Tests', () {
    test('Singleton instance should be identical', () {
      final instance1 = AsrHandler();
      final instance2 = AsrHandler();
      expect(identical(instance1, instance2), isTrue);
    });
  });
}
