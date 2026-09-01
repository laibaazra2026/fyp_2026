import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/command_service.dart';
import 'services/intruder_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("📩 Background message received: ${message.data}");

  String type = message.data['type'] ?? '';

  if (type == 'LOCK') {
    const platform = MethodChannel('device_protection/admin');
    try {
      await platform.invokeMethod('lockDevice');
      print("🔒 Phone locked successfully from background push!");
    } catch (e) {
      print("❌ Failed to lock phone from background: $e");
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null) {
        print(
          "🔑 Auth state active for user: ${user.uid}. Initializing command listener...",
        );

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

  void _initIntruderListener() {
    _adminChannel.setMethodCallHandler((call) async {
      if (call.method == "onPasswordFailed") {
        print("🚨 Intruder alert signal received from native Android!");

        final intruderService = IntruderService();
        await intruderService.onIncorrectUnlockAttempt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Device Protection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
