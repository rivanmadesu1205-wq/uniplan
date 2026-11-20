import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth/auth_bloc.dart';
import 'pages/home/home_page.dart';
import 'pages/schedule/jadwal_page.dart';
import 'pages/notes/catatan_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/settings/pengaturan_page.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('Supabase initialization started');
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 10));
    debugPrint('Supabase initialization completed');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const UniPlanApp());
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.instance.initialize().timeout(
      const Duration(seconds: 5),
    );
    debugPrint('NotificationService initialization completed');
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }
}

class UniPlanApp extends StatefulWidget {
  const UniPlanApp({super.key});

  @override
  State<UniPlanApp> createState() => _UniPlanAppState();
}

class _UniPlanAppState extends State<UniPlanApp> {
  late final AuthBloc _authBloc;
  AppThemeMode _themeMode = AppThemeMode.terang;
  bool _isSplashShowing = true;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc()..add(const AuthStarted());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  ThemeMode get _currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.terang:
        return ThemeMode.light;
      case AppThemeMode.gelap:
        return ThemeMode.dark;
      case AppThemeMode.sistem:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp(
        title: 'UniPlan',
        debugShowCheckedModeBanner: false,
        themeMode: _currentThemeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          cardColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3563E9),
            primary: const Color(0xFF3563E9),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardColor: const Color(0xFF1E293B),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3563E9),
            primary: const Color(0xFF3563E9),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (_isSplashShowing) {
              return SplashScreen(
                onSplashFinished: () {
                  setState(() => _isSplashShowing = false);
                },
              );
            }

            if (authState is AuthAuthenticated) {
              return MainPage(
                currentTheme: _themeMode,
                onThemeChanged: (newTheme) =>
                    setState(() => _themeMode = newTheme),
                onLogout: () =>
                    context.read<AuthBloc>().add(const AuthLogoutRequested()),
              );
            }

            return LoginPage(onLoginSuccess: () {});
          },
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onSplashFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3563E9).withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF3563E9),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'UniPlan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Jadwal Kuliah & Perencanaan Belajar',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFF3563E9),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final AppThemeMode currentTheme;
  final ValueChanged<AppThemeMode> onThemeChanged;
  final VoidCallback onLogout;

  const MainPage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncAlarms();
  }

  Future<void> _syncAlarms() async {
    try {
      final schedules = await DatabaseService.instance.getAllJadwal();
      await NotificationService.instance.syncAllAlarms(schedules);
    } catch (e, stackTrace) {
      debugPrint('Failed to sync scheduled alarms: $e\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(isActive: _currentIndex == 0),
      JadwalPage(isActive: _currentIndex == 1),
      CatatanPage(isActive: _currentIndex == 2),
      PengaturanPage(
        currentTheme: widget.currentTheme,
        onThemeChanged: widget.onThemeChanged,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Beranda'),
          _buildNavItem(1, Icons.calendar_today_rounded, 'Jadwal'),
          _buildNavItem(2, Icons.note_alt_rounded, 'Catatan'),
          _buildNavItem(3, Icons.settings_rounded, 'Pengaturan'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF4FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF3563E9)
                  : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF3563E9)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
