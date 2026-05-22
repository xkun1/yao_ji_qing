import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../viewmodels/home_viewmodel.dart';
import 'scanner_screen.dart';
import 'setup_guide_screen.dart';
import 'ai_chat_screen.dart';
import 'stats_screen.dart';
import '../widgets/manual_medication_sheet.dart';
import '../widgets/firework_painter.dart';
import '../widgets/feature_guide_overlay.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/progress_card.dart';
import '../widgets/home/arc_menu.dart';
import '../widgets/home/home_bottom_bar.dart';
import '../widgets/home/med_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  // 定位锚点
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _firstTaskKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  final GlobalKey _deleteKey = GlobalKey();

  late final List<FireworkParticle> _fireworkParticles;

  late AnimationController _animationController;
  late AnimationController _celebrationController;
  OverlayEntry? _celebrationOverlay;
  int _celebrationRunId = 0;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    
    // 延迟获取 provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().initData();
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fireworkParticles = _buildFireworkParticles();

    // 启动引导逻辑
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SetupGuideScreen.checkAndShow(context);

      final prefs = await SharedPreferences.getInstance();
      final bool needGuide = !(prefs.getBool('feature_guide_done_v5') ?? false);

      if (needGuide && mounted) {
        final viewModel = context.read<HomeViewModel>();
        viewModel.startGuide();

        await viewModel.loadTodayTasks();
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          await FeatureGuideOverlay.checkAndShow(
            context,
            settingsKey: _settingsKey,
            progressKey: _progressKey,
            fabKey: _fabKey,
            statsKey: _statsKey,
            firstTaskKey: _firstTaskKey,
            editKey: _editKey,
            deleteKey: _deleteKey,
            onFinish: () {
              if (mounted) {
                viewModel.endGuide();
              }
            },
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _celebrationOverlay?.remove();
    _animationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _handlePickImage(ImageSource source) async {
    _toggleMenu();
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ScannerScreen(initialImage: image)),
      );
      if (result == true && mounted) {
        context.read<HomeViewModel>().loadTodayTasks();
      }
    }
  }

  Future<void> _handleCameraEntry() => _handlePickImage(ImageSource.camera);

  Future<void> _handleManualEntry() async {
    _toggleMenu();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ManualMedicationSheet(),
    );
    if (saved == true && mounted) {
      context.read<HomeViewModel>().loadTodayTasks();
    }
  }

  Future<void> _handleAIChatEntry() {
    _toggleMenu();
    return Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const AIChatScreen()));
  }

  Future<void> _handleEditMedication(TodayMedicationTask task) async {
    final viewModel = context.read<HomeViewModel>();
    if (viewModel.isGuiding) return;
    
    await task.medicine.reminders.load();
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualMedicationSheet(medicine: task.medicine),
    );
    if (saved == true && mounted) {
      viewModel.loadTodayTasks();
    }
  }

  List<FireworkParticle> _buildFireworkParticles() {
    final random = math.Random(20260416);
    final particles = <FireworkParticle>[];
    const centers = [
      Offset(0.18, 0.18),
      Offset(0.50, 0.24),
      Offset(0.82, 0.18),
      Offset(0.25, 0.50),
      Offset(0.75, 0.54),
      Offset(0.50, 0.76),
    ];
    const colors = [
      Color(0xFFF97316),
      Color(0xFFFFD166),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFEC4899)
    ];

    for (final center in centers) {
      for (var i = 0; i < 28; i++) {
        particles.add(FireworkParticle(
          center: center,
          angle: (math.pi * 2 / 28) * i + random.nextDouble() * 0.18,
          distance: 90 + random.nextDouble() * 120,
          color: colors[(i + centers.indexOf(center)) % colors.length],
          delay: random.nextDouble() * 0.26,
          size: 3 + random.nextDouble() * 4,
        ));
      }
    }
    return particles;
  }

  void _showCompletionCelebration() {
    if (!mounted) return;
    final runId = ++_celebrationRunId;
    _celebrationController.stop();
    _celebrationController.forward(from: 0);
    _celebrationOverlay?.remove();
    _celebrationOverlay = OverlayEntry(
        builder: (context) => _buildCompletionCelebrationOverlay());
    Overlay.of(context).insert(_celebrationOverlay!);

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted || runId != _celebrationRunId) return;
      _celebrationOverlay?.remove();
      _celebrationOverlay = null;
      _celebrationController.reset();
    });
  }

  Widget _buildCompletionCelebrationOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _celebrationController,
          builder: (context, child) {
            return CustomPaint(
                painter: FireworkPainter(
                    progress: _celebrationController.value,
                    particles: _fireworkParticles),
                size: Size.infinite);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          viewModel.currentIndex == 0 ? _buildHomeBody(viewModel) : const StatsScreen(),
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => Container(
                  color: Colors.black
                      .withValues(alpha: 0.3 * _animationController.value),
                ),
              ),
            ),
          ArcMenuOverlay(
            isOpen: _isMenuOpen,
            animationController: _animationController,
            onCameraEntry: _handleCameraEntry,
            onManualEntry: _handleManualEntry,
            onAIChatEntry: _handleAIChatEntry,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildMainFab(),
      bottomNavigationBar: HomeBottomBar(statsKey: _statsKey),
    );
  }

  Widget _buildHomeBody(HomeViewModel viewModel) {
    return SafeArea(
      bottom: false,
      child: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                HomeHeader(settingsKey: _settingsKey),
                ProgressCard(
                  progressKey: _progressKey,
                  onCelebrationRequested: _showCompletionCelebration,
                ),
                const MedListHeader(),
                MedList(
                  firstTaskKey: _firstTaskKey,
                  editKey: _editKey,
                  deleteKey: _deleteKey,
                  onEdit: _handleEditMedication,
                  onMarkTaken: (task) => viewModel.markTaskTaken(task, _showCompletionCelebration),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildMainFab() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animationController.value * math.pi / 4,
          child: FloatingActionButton(
            key: _fabKey,
            onPressed: _toggleMenu,
            backgroundColor: const Color(0xFF3B82F6),
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        );
      },
    );
  }
}
