import 'package:flutter/material.dart';
import '../views/home_screen.dart';
import '../views/settings_screen.dart';
import '../views/stats_screen.dart';
import '../views/about_screen.dart';
import '../views/license_screen.dart';
import '../views/privacy_policy_screen.dart';
import '../views/model_manager_screen.dart';
import '../views/scanner_screen.dart';
import '../views/ai_chat_screen.dart';
import '../views/setup_guide_screen.dart';

/// 集中路由管理
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String settings = '/settings';
  static const String modelManager = '/model-manager';
  static const String aiChat = '/ai-chat';
  static const String scanner = '/scanner';
  static const String stats = '/stats';
  static const String about = '/about';
  static const String license = '/license';
  static const String privacyPolicy = '/privacy-policy';
  static const String setupGuide = '/setup-guide';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == home) return _page(const HomeScreen(), settings);
    if (name == AppRoutes.settings) {
      return _page(const SettingsScreen(), settings);
    }
    if (name == modelManager) {
      return _page(const ModelManagerScreen(), settings);
    }
    if (name == aiChat) return _page(const AIChatScreen(), settings);
    if (name == scanner) {
      final args = settings.arguments;
      if (args is ScannerRouteArgs) {
        return _page(ScannerScreen(initialImage: args.initialImage), settings);
      }
      return _page(const ScannerScreen(), settings);
    }
    if (name == stats) return _page(const StatsScreen(), settings);
    if (name == about) return _page(const AboutScreen(), settings);
    if (name == license) return _page(const LicenseScreen(), settings);
    if (name == privacyPolicy) {
      return _page(const PrivacyPolicyScreen(), settings);
    }
    if (name == setupGuide) return _page(const SetupGuideScreen(), settings);
    return _page(const HomeScreen(), settings);
  }

  static PageRouteBuilder _page(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}

/// 扫描器页面路由参数
class ScannerRouteArgs {
  final dynamic initialImage;
  const ScannerRouteArgs({this.initialImage});
}
