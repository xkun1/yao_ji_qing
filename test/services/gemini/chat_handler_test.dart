import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/services/gemini/chat_handler.dart';

// 我们可以编写一些状态相关的基础测试
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatHandler Tests', () {
    test('Singleton instance should be identical', () {
      final instance1 = ChatHandler();
      final instance2 = ChatHandler();
      expect(identical(instance1, instance2), isTrue);
    });
  });
}
