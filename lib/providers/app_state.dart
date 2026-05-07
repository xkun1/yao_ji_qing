import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/exceptions.dart';
import '../services/gemini_service.dart';

/// 应用状态管理
class AppState extends ChangeNotifier {
  AppState._internal();

  static final AppState _instance = AppState._internal();

  factory AppState() => _instance;

  final GeminiService _geminiService = GeminiService();

  // 加载状态
  bool _isLoading = false;
  bool _isInitialized = false;

  // 模型状态
  ModelState _modelState = ModelState.none;
  bool _asrReady = false;
  bool _ttsReady = false;

  // 设置状态
  bool _autoSpeak = false;

  // 错误状态
  AppException? _lastError;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  ModelState get modelState => _modelState;
  bool get asrReady => _asrReady;
  bool get ttsReady => _ttsReady;
  bool get autoSpeak => _autoSpeak;
  AppException? get lastError => _lastError;

  GeminiService get geminiService => _geminiService;

  /// 初始化应用
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      await _geminiService.init();
      await _loadSettings();
      await _refreshModelStates();
      _isInitialized = true;
    } catch (e) {
      _setError(ExceptionConverter.convert(e));
    } finally {
      _setLoading(false);
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSpeak = prefs.getBool(AppConstants.autoSpeakKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('加载设置失败: $e');
    }
  }

  /// 保存设置
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.autoSpeakKey, _autoSpeak);
      _geminiService.autoSpeak = _autoSpeak;
    } catch (e) {
      _setError(ExceptionConverter.convert(e));
    }
  }

  /// 刷新模型状态
  Future<void> refreshModelStates() async {
    _setLoading(true);
    try {
      await _refreshModelStates();
    } catch (e) {
      _setError(ExceptionConverter.convert(e));
    } finally {
      _setLoading(false);
    }
  }

  /// 刷新模型状态（内部方法）
  Future<void> _refreshModelStates() async {
    _modelState = await _geminiService.getModelState();
    _asrReady = await _geminiService.checkAsrFilesExist();
    _ttsReady = await _geminiService.checkTtsFilesExist();
    notifyListeners();
  }

  /// 设置自动语音
  void setAutoSpeak(bool value) {
    if (_autoSpeak != value) {
      _autoSpeak = value;
      _geminiService.autoSpeak = value;
      saveSettings();
      notifyListeners();
    }
  }

  /// 设置加载状态
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// 设置错误
  void _setError(AppException? error) {
    if (_lastError != error) {
      _lastError = error;
      notifyListeners();
    }
  }

  /// 清除错误
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// 检查模型是否就绪
  bool get isModelReady => _modelState == ModelState.ready;

  /// 检查所有功能是否就绪
  bool get isAllReady => isModelReady && _asrReady && _ttsReady;

  /// 获取就绪状态描述
  String get readinessDescription {
    if (isAllReady) return '所有功能已就绪';
    if (!isModelReady) return 'AI 引擎未就绪';
    if (!_asrReady) return '语音识别未就绪';
    if (!_ttsReady) return '语音合成未就绪';
    return '部分功能未就绪';
  }

  @override
  void dispose() {
    _geminiService.dispose();
    super.dispose();
  }
}