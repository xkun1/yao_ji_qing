import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/routes.dart';
import 'providers/app_state.dart';
import 'providers/model_download_state.dart';
import 'providers/settings_state.dart';
import 'services/database_service.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final notifService = NotificationService();
  await notifService.init();

  final dbService = DatabaseService();
  await dbService.init();

  // 初始化 AI 引擎（清理残留任务 + 加载设置 + ensureInitialized）
  final geminiService = GeminiService();
  await geminiService.init();

  runApp(const YaoJiQingApp());
}

class YaoJiQingApp extends StatelessWidget {
  const YaoJiQingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsState>(
          create: (_) => SettingsState()..init(),
        ),
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ChangeNotifierProvider<ModelDownloadState>(
          create: (_) => ModelDownloadState()..init(),
        ),
      ],
      child: MaterialApp(
        title: '药记清',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            primary: const Color(0xFF3B82F6),
            onPrimary: Colors.white,
            secondary: const Color(0xFF10B981),
            surface: const Color(0xFFFFFFFF),
            surfaceContainerHighest: const Color(0xFFF9FAFB),
          ),
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Color(0xFF1F2937)),
          ),
        ),
        home: const SplashScreen(),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
