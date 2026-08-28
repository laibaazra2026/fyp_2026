import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/command_service.dart';
import 'services/intruder_service.dart';

// ✅ 1. GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final CommandService _commandService = CommandService();
  final MethodChannel _adminChannel = const MethodChannel(
    'device_protection/admin',
  );
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initIntruderListener();

    // ✅ 2. DYNAMICALLY LISTEN TO AUTH STATE CHANGES
    // This starts command listening automatically the second a user logs in or boots up logged in.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null) {
        print(
          "🔑 Auth state active for user: ${user.uid}. Initializing command listener...",
        );

        // Safe delayed call to ensure context/navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final activeContext = navigatorKey.currentContext ?? context;
          _commandService.listenForCommands(activeContext);
        });
      } else {
        print("🔒 User logged out. Commands listener paused.");
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // 👈 Listens for the failed unlock event coming from native Android
  void _initIntruderListener() {
    _adminChannel.setMethodCallHandler((call) async {
      if (call.method == "onPasswordFailed") {
        print("🚨 Intruder alert signal received from native Android!");

        // Trigger your core camera capture and upload service
        final intruderService = IntruderService();
        await intruderService.onIncorrectUnlockAttempt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ 3. ATTACH THE KEY HERE
      title: 'Device Protection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
