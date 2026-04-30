import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini/tts_handler.dart';

void main() {
  group('TtsHandler Tests', () {
    late TtsHandler ttsHandler;

    setUp(() {
      ttsHandler = TtsHandler();
      // 在测试环境中，可以通过设置属性确保它们状态隔离
    });

    test('Singleton instance should be identical', () {
      final instance1 = TtsHandler();
      final instance2 = TtsHandler();
      expect(identical(instance1, instance2), isTrue);
    });

    test('autoSpeak should be initialized to false by default', () {
      expect(ttsHandler.autoSpeak, isFalse);
    });

    test('autoSpeak can be set', () {
      ttsHandler.autoSpeak = true;
      expect(ttsHandler.autoSpeak, isTrue);

      ttsHandler.autoSpeak = false;
      expect(ttsHandler.autoSpeak, isFalse);
    });
  });
}
