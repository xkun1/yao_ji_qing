import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yao_ji_qing/core/routes.dart';

void main() {
  group('App 路由', () {
    test('所有命名路由可生成非空 Route', () {
      final routes = [
        AppRoutes.home,
        AppRoutes.settings,
        AppRoutes.modelManager,
        AppRoutes.aiChat,
        AppRoutes.scanner,
        AppRoutes.stats,
        AppRoutes.about,
        AppRoutes.license,
        AppRoutes.privacyPolicy,
        AppRoutes.setupGuide,
      ];

      for (final route in routes) {
        final generated =
            AppRoutes.generateRoute(RouteSettings(name: route));
        expect(generated, isNotNull,
            reason: '路由 $route 生成失败');
      }
    });

    test('未知路由回退到 HomeScreen', () {
      final generated =
          AppRoutes.generateRoute(const RouteSettings(name: '/nonexistent'));
      expect(generated, isNotNull);
    });

    test('ScannerRouteArgs 默认 initialImage 为 null', () {
      const args = ScannerRouteArgs();
      expect(args.initialImage, isNull);
    });

    test('Scanner 路由无参数时正常生成', () {
      final generated = AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.scanner),
      );
      expect(generated, isNotNull);
    });
  });
}
