import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/command_service.dart';
import 'services/intruder_service.dart';
import 'services/background_task.dart';
import 'services/sim_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      // Run background SIM swap check
      SimService simService = SimService();
      await simService.checkPhysicalSimSwap();

      print("Background SIM check executed successfully.");
    } catch (e) {
      print("Background SIM check error: $e");
    }
    return Future.value(true);
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 Background message received in headless isolate: ${message.data}");
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Workmanager for background tasks (like SIM swap monitoring)
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register periodic background task (runs approximately every 15 minutes)
  Workmanager().registerPeriodicTask(
    "sim_swap_background_task_id",
    "checkSimSwapTask",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

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
    startService();

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
