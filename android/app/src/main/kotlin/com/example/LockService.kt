package com.example.device_protection

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class LockService : Service() {
    companion object {
        private const val TAG = "LockService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "device_protection_channel"
        var wrongAttempts = 0
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
                }
                Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "Phone unlocked successfully")
                    wrongAttempts = 0
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        Log.d(TAG, "✅ LockService started as FOREGROUND SERVICE")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkLockState() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        
        if (keyguardManager.isKeyguardLocked) {
            wrongAttempts++
            Log.d(TAG, "Wrong attempt: $wrongAttempts")
            
            if (wrongAttempts >= 3) {
                Log.d(TAG, "3 wrong attempts! Capturing intruder photo...")
                captureIntruderPhoto()
                wrongAttempts = 0
            }
        }
    }

    private fun captureIntruderPhoto() {
        try {
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Device Protection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps device protection running in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ Device Protection")
            .setContentText("Monitoring your device for security threats")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: IllegalArgumentException) {
            Log.d(TAG, "Receiver already unregistered")
        }
        super.onDestroy()
        Log.d(TAG, "LockService destroyed")
    }
}