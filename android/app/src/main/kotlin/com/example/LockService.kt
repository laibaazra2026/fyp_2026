package com.example.device_protection

import android.app.KeyguardManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

class LockService : Service() {
    companion object {
        private const val TAG = "LockService"
        var wrongAttempts = 0
        var lastScreenState = false
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen ON")
                    checkLockState()
                }
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen OFF")
                    lastScreenState = false
                }
                Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "User present (phone unlocked successfully)")
                    wrongAttempts = 0
                    lastScreenState = true
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        Log.d(TAG, "LockService created")
    }

    private fun checkLockState() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        
        if (keyguardManager.isKeyguardLocked) {
            // Phone is locked, someone is trying to unlock
            Log.d(TAG, "Phone is locked, someone is trying to unlock")
            wrongAttempts++
            Log.d(TAG, "Wrong attempt: $wrongAttempts")
            
            if (wrongAttempts >= 3) {
                Log.d(TAG, "3 wrong attempts! Capturing intruder photo...")
                captureIntruderPhoto()
                wrongAttempts = 0
            }
        } else {
            Log.d(TAG, "Phone is not locked")
        }
    }

    private fun captureIntruderPhoto() {
        try {
            // Send signal to Flutter to capture photo
            val channel = MethodChannel(
                (applicationContext as? android.app.Application)?.let {
                    (it as? io.flutter.embedding.engine.FlutterEngine)?.dartExecutor?.binaryMessenger
                } ?: return,
                "com.example.device_protection/lock"
            )
            channel.invokeMethod("capturePhoto", null)
            Log.d(TAG, "📸 Photo capture triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering photo capture: ${e.message}")
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
        unregisterReceiver(screenReceiver)
        Log.d(TAG, "LockService destroyed")
    }
}