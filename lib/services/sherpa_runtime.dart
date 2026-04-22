import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class SherpaRuntime {
  SherpaRuntime._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    sherpa.initBindings();
    _initialized = true;
  }
}
