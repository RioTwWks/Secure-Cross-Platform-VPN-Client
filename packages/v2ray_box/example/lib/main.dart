import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import 'pages/home_page.dart';
import 'pages/logs_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const V2RayBoxApp());
}

class V2RayBoxApp extends StatelessWidget {
  const V2RayBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Ray Box',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00D9FF),
          surface: const Color(0xFF1A1A2E),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final V2rayBox _v2rayBox = V2rayBox();
  int _currentIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _v2rayBox.initialize(notificationStopButtonText: 'Stop');
    } catch (e) {
      debugPrint('Init error: $e');
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      HomePage(v2rayBox: _v2rayBox),
      LogsPage(v2rayBox: _v2rayBox),
      SettingsPage(v2rayBox: _v2rayBox),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: const Color(0xFF6C5CE7).withOpacity(0.3),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
