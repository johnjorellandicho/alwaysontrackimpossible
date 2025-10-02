import 'package:flutter/material.dart';
import 'dart:async';

// Import your screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/email_verification_screen.dart'; // this imports EmailVerificationScreen + UserRole
import 'screens/dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/language_service.dart';
import 'firebase_options.dart';
import 'models/user_role.dart';
import 'screens/setting_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize language service
  final languageService = LanguageService();
  await languageService.loadLanguage();

  runApp(
    ChangeNotifierProvider.value(
      value: languageService,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlwaysOnTrack',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/email-verification') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: args['email'] as String,
              userRole: args['userRole'] as UserRole,  // ✅ fixed
              firstName: args['firstName'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showWaves = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _showWaves = true);
      _controller.forward();
    });

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red, Colors.redAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/alwaysontracklogo.png',
              height: 170,
              width: 170,
            ),
          ),
          if (_showWaves)
            FadeTransition(
              opacity: _animation,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.lightGreen],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
