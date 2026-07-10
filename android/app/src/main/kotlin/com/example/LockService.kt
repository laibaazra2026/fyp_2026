package com.example.device_protection

import android.app.Service
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class LockService : Service() {
    companion object {
        private const val TAG = "LockService"
        var wrongAttempts = 0
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_ON) {
                // Screen turned on, check lock attempts
                checkLockAttempts()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        // Register receiver for screen on events
        registerReceiver(receiver, IntentFilter(Intent.ACTION_SCREEN_ON))
        Log.d(TAG, "LockService created")
    }

    private fun checkLockAttempts() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        
        if (keyguardManager.isKeyguardLocked) {
            // Phone is locked
            Log.d(TAG, "Phone is locked")
        } else {
            // Phone was unlocked
            Log.d(TAG, "Phone was unlocked successfully")
            wrongAttempts = 0
        }
    }

    fun recordWrongAttempt() {
        wrongAttempts++
        Log.d(TAG, "Wrong attempt: $wrongAttempts")
        
        if (wrongAttempts >= 3) {
            Log.d(TAG, "3 wrong attempts! Capturing photo...")
            // Send to Flutter to capture photo
            MethodChannel(
                (applicationContext as? android.app.Application)?.let {
                    it as io.flutter.embedding.engine.FlutterEngine? 
                }?.dartExecutor?.binaryMessenger ?: return,
                "com.example.device_protection/lock"
            ).invokeMethod("capturePhoto", null)
            wrongAttempts = 0
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(receiver)
        Log.d(TAG, "LockService destroyed")
    }
}