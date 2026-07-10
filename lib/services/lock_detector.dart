import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LockDetector {
  static const MethodChannel _channel = MethodChannel(
    'com.example.device_protection/lock',
  );

  // ========== START DETECTING WRONG ATTEMPTS ==========
  static void startListening(Function onWrongAttempt) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWrongAttempt') {
        onWrongAttempt();
      }
    });
  }

  // ========== CHECK IF DEVICE HAS LOCK ==========
  static Future<bool> hasDeviceLock() async {
    try {
      final bool result = await _channel.invokeMethod('hasDeviceLock');
      return result;
    } catch (e) {
      print('❌ Error checking device lock: $e');
      return false;
    }
  }
}
