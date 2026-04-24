import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// 设置状态管理
class SettingsState extends ChangeNotifier {
  SettingsState._internal();

  static final SettingsState _instance = SettingsState._internal();

  factory SettingsState() => _instance;

  // 设置项
  bool _autoSpeak = false;
  bool _notificationsEnabled = true;
  String _language = 'zh';
  bool _firstLaunch = true;

  bool get autoSpeak => _autoSpeak;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  bool get firstLaunch => _firstLaunch;

  /// 初始化设置
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSpeak = prefs.getBool(AppConstants.autoSpeakKey) ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _language = prefs.getString(AppConstants.languageKey) ?? 'zh';
      _firstLaunch = prefs.getBool(AppConstants.firstLaunchKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('初始化设置失败: $e');
    }
  }

  /// 设置自动语音
  Future<void> setAutoSpeak(bool value) async {
    if (_autoSpeak != value) {
      _autoSpeak = value;
      await _saveSetting(AppConstants.autoSpeakKey, value);
      notifyListeners();
    }
  }

  /// 设置通知启用
  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled != value) {
      _notificationsEnabled = value;
      await _saveSetting('notifications_enabled', value);
      notifyListeners();
    }
  }

  /// 设置语言
  Future<void> setLanguage(String value) async {
    if (_language != value) {
      _language = value;
      await _saveSetting(AppConstants.languageKey, value);
      notifyListeners();
    }
  }

  /// 设置首次启动
  Future<void> setFirstLaunch(bool value) async {
    if (_firstLaunch != value) {
      _firstLaunch = value;
      await _saveSetting(AppConstants.firstLaunchKey, value);
      notifyListeners();
    }
  }

  /// 保存设置
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }

  /// 重置所有设置
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await init();
    } catch (e) {
      debugPrint('重置设置失败: $e');
    }
  }

  /// 导出设置
  Map<String, dynamic> exportSettings() {
    return {
      'autoSpeak': _autoSpeak,
      'notificationsEnabled': _notificationsEnabled,
      'language': _language,
      'firstLaunch': _firstLaunch,
    };
  }

  /// 导入设置
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      if (settings.containsKey('autoSpeak')) {
        await setAutoSpeak(settings['autoSpeak'] as bool);
      }
      if (settings.containsKey('notificationsEnabled')) {
        await setNotificationsEnabled(settings['notificationsEnabled'] as bool);
      }
      if (settings.containsKey('language')) {
        await setLanguage(settings['language'] as String);
      }
      if (settings.containsKey('firstLaunch')) {
        await setFirstLaunch(settings['firstLaunch'] as bool);
      }
    } catch (e) {
      debugPrint('导入设置失败: $e');
    }
  }
}