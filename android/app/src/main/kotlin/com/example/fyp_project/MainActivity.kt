package com.example.device_protection

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.device_protection/lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLockService" -> {
                        startLockService()
                        result.success(true)
                    }
                    "capturePhoto" -> {
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startLockService() {
        val intent = Intent(this, LockService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        println("✅ LockService started as foreground service")
    }
}