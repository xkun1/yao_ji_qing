import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/model_download_state.dart';
import '../providers/settings_state.dart';
import '../services/gemini_service.dart';
import '../services/local_asr_service.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/stats_viewmodel.dart';

/// Provider 配置
class ProviderConfig {
  /// 创建所有 Provider
  static List<ChangeNotifierProvider<dynamic>> createProviders() {
    return [
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState()..initialize(),
      ),
      ChangeNotifierProvider<ModelDownloadState>(
        create: (_) => ModelDownloadState()..init(),
      ),
      ChangeNotifierProvider<SettingsState>(
        create: (_) => SettingsState()..init(),
      ),
      ChangeNotifierProvider<HomeViewModel>(
        create: (_) => HomeViewModel(),
      ),
      ChangeNotifierProvider<StatsViewModel>(
        create: (_) => StatsViewModel(),
      ),
      ChangeNotifierProvider<ChatViewModel>(
        create: (_) => ChatViewModel(GeminiService(), LocalAsrService()),
      ),
    ];
  }

  /// 获取应用状态
  static AppState ofApp(BuildContext context) {
    return Provider.of<AppState>(context, listen: false);
  }

  /// 获取模型下载状态
  static ModelDownloadState ofModelDownload(BuildContext context) {
    return Provider.of<ModelDownloadState>(context, listen: false);
  }

  /// 获取设置状态
  static SettingsState ofSettings(BuildContext context) {
    return Provider.of<SettingsState>(context, listen: false);
  }

  /// 监听应用状态
  static AppState watchApp(BuildContext context) {
    return Provider.of<AppState>(context);
  }

  /// 监听模型下载状态
  static ModelDownloadState watchModelDownload(BuildContext context) {
    return Provider.of<ModelDownloadState>(context);
  }

  /// 监听设置状态
  static SettingsState watchSettings(BuildContext context) {
    return Provider.of<SettingsState>(context);
  }
}

/// Provider 扩展方法
extension ProviderContext on BuildContext {
  /// 获取应用状态
  AppState get appState => ProviderConfig.ofApp(this);

  /// 获取模型下载状态
  ModelDownloadState get modelDownloadState =>
      ProviderConfig.ofModelDownload(this);

  /// 获取设置状态
  SettingsState get settingsState => ProviderConfig.ofSettings(this);

  /// 监听应用状态
  AppState get watchAppState => ProviderConfig.watchApp(this);

  /// 监听模型下载状态
  ModelDownloadState get watchModelDownloadState =>
      ProviderConfig.watchModelDownload(this);

  /// 监听设置状态
  SettingsState get watchSettingsState => ProviderConfig.watchSettings(this);
}
