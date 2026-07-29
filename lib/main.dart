import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/command_service.dart';

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
  // final IntruderService _intruderService = IntruderService();  // ← REMOVE

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commandService.listenForCommands(context);
    });

    // _intruderService.startListening();  // ← REMOVE
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Protection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
