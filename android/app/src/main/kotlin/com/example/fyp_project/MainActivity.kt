package com.example.device_protection

import android.app.KeyguardManager
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.device_protection/lock"
    private var wrongAttemptCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "onWrongAttempt" -> {
                        wrongAttemptCount++
                        println("⚠️ Wrong attempt $wrongAttemptCount")
                        
                        if (wrongAttemptCount >= 3) {
                            println("📸 3 wrong attempts! Capturing photo...")
                            // Send to Flutter to capture photo
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                .invokeMethod("capturePhoto", null)
                            wrongAttemptCount = 0
                        }
                        result.success(true)
                    }
                    "hasDeviceLock" -> {
                        val hasLock = hasDeviceLock()
                        result.success(hasLock)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasDeviceLock(): Boolean {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isDeviceSecure
    }
}