/*import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'ui/login_screen.dart';
import 'ui/brand_splash.dart';
import 'ui/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6FFF)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Translation Call',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const _SplashThenAuth(),
    );
  }
}

class _SplashThenAuth extends StatefulWidget {
  const _SplashThenAuth();

  @override
  State<_SplashThenAuth> createState() => _SplashThenAuthState();
}

class _SplashThenAuthState extends State<_SplashThenAuth> {
  static const _splashSeconds = 3;

  int _secondsLeft = _splashSeconds;
  bool _done = false;
  Timer? _countdownTimer;
  bool _showShell = false;

  @override
  void initState() {
    super.initState();

    // Countdown timer to ensure splash always appears first.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
      }
    });

    Future<void>.delayed(const Duration(seconds: _splashSeconds), () {
      if (!mounted) return;
      _countdownTimer?.cancel();
      setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return BrandSplash(secondsLeft: _secondsLeft);
    }

    if (_showShell) {
      // Logout ke baad wapas login aaye, is liye shell state mein auth stream listen karte hain.
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return LoginScreen(onLoginSuccess: () => setState(() => _showShell = true));
          }
          return const ShellScreen();
        },
      );
    }

    return LoginScreen(
      onLoginSuccess: () => setState(() => _showShell = true),
    );
  }
}*/



/*import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'ui/brand_splash.dart';
import 'ui/login_screen.dart';
import 'ui/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX: Prevent duplicate Firebase initialization
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6FFF)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Translation Call',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const SplashThenAuth(),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class SplashThenAuth extends StatefulWidget {
  const SplashThenAuth({super.key});

  @override
  State<SplashThenAuth> createState() => _SplashThenAuthState();
}

class _SplashThenAuthState extends State<SplashThenAuth> {
  static const int splashSeconds = 3;

  int secondsLeft = splashSeconds;
  bool done = false;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();

    // ⏳ countdown timer
    countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (secondsLeft <= 0) return;

      setState(() => secondsLeft--);

      if (secondsLeft <= 0) {
        timer.cancel();
      }
    });

    // ⏳ delay for splash
    Future.delayed(const Duration(seconds: splashSeconds), () {
      if (!mounted) return;
      countdownTimer?.cancel();
      setState(() => done = true);
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show Splash first
    if (!done) {
      return BrandSplash(secondsLeft: secondsLeft);
    }

    // ✅ Firebase auth check (FIXED FLOW)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 🔄 loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // ❌ Not logged in
        if (user == null) {
          return LoginScreen(
            onLoginSuccess: () {
              setState(() {}); // rebuild UI
            },
          );
        }

        // ✅ Logged in
       return const ShellScreen();
       
      },
    );
  }
}*/

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'ui/brand_splash.dart';
import 'ui/login_screen.dart';
import 'ui/main_dashboard.dart'; // ✅ NEW IMPORT

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX: prevent duplicate Firebase initialization
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const AppRoot());
}

// ─────────────────────────────────────────────

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C6FFF),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Translation Call',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const SplashThenAuth(),
    );
  }
}

// ─────────────────────────────────────────────

class SplashThenAuth extends StatefulWidget {
  const SplashThenAuth({super.key});

  @override
  State<SplashThenAuth> createState() => _SplashThenAuthState();
}

class _SplashThenAuthState extends State<SplashThenAuth> {
  static const int splashSeconds = 3;

  int secondsLeft = splashSeconds;
  bool done = false;
  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();

    // ⏳ countdown timer
    countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (secondsLeft <= 0) return;

      setState(() => secondsLeft--);

      if (secondsLeft <= 0) {
        timer.cancel();
      }
    });

    // ⏳ splash delay
    Future.delayed(const Duration(seconds: splashSeconds), () {
      if (!mounted) return;
      countdownTimer?.cancel();
      setState(() => done = true);
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Splash screen
    if (!done) {
      return BrandSplash(secondsLeft: secondsLeft);
    }

    // ✅ 2. Auth check
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 🔄 Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // ❌ Not logged in → Login Screen
        if (user == null) {
          return LoginScreen(
            onLoginSuccess: () {
              setState(() {}); // rebuild after login
            },
          );
        }

        // ✅ Logged in → Dashboard
        return const MainDashboard();
      },
    );
  }
}




