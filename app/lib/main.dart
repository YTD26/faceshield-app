import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/photo_mode_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/video_mode_screen.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FaceShieldApp());
}

class FaceShieldApp extends StatelessWidget {
  const FaceShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceShield',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1A237E),
        scaffoldBackgroundColor: const Color(0xFF070B24),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BCD4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1A237E),
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A237E),
      ),
      home: const MainNavigation(),
      routes: {
        '/photo': (_) => const PhotoModeScreen(),
        '/video': (_) => const VideoModeScreen(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final given = await StorageService.hasConsentBeenGiven();
    if (!given && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConsentDialog();
      });
    }
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1442),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF00BCD4)),
            SizedBox(width: 12),
            Text(
              'Privacy Notice',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to FaceShield',
                style: TextStyle(
                  color: Color(0xFF00BCD4),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'FaceShield processes your photos and videos to detect and blur faces. Here\\'s how we handle your data:',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 16),
              _ConsentItem(
                icon: Icons.cloud_upload,
                text:
                    'Photos and videos are temporarily uploaded to our server for AI processing.',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.timer,
                text:
                    'All uploaded files are automatically deleted within 60 seconds after processing.',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.no_accounts,
                text:
                    'No face data, biometric information, or personal data is stored on our servers.',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.phone_android,
                text:
                    'Your processing history is stored only on your device and can be deleted at any time.',
              ),
              SizedBox(height: 8),
              _ConsentItem(
                icon: Icons.gpp_good,
                text:
                    'We comply with GDPR and respect your right to data privacy.',
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await StorageService.setConsentGiven(true);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'I Understand & Accept',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1442),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF00BCD4),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConsentItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00BCD4), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
