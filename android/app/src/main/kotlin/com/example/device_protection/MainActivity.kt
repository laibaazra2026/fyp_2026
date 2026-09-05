package com.example.device_protection

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "device_protection/admin"
    private var activeRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, MyAdminReceiver::class.java)

            when (call.method) {
                "isDeviceAdminActive" -> {
                    result.success(dpm.isAdminActive(adminComponent))
                }
                "enableAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                        putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                        putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Admin permission is required to detect wrong password attempts and lock the device remotely.")
                    }
                    startActivityForResult(intent, 1001)
                    result.success("Admin prompt opened")
                }
                "lockDevice" -> {
                    if (dpm.isAdminActive(adminComponent)) {
                        dpm.lockNow()
                        result.success("Device locked successfully")
                    } else {
                        result.error("ADMIN_NOT_ACTIVE", "Device Admin is not enabled", null)
                    }
                }
                "ringAlarm" -> {
                    try {
                        val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                        activeRingtone?.stop()
                        activeRingtone = RingtoneManager.getRingtone(applicationContext, notification)
                        activeRingtone?.play()
                        result.success("Alarm ringing successfully")
                    } catch (e: Exception) {
                        result.error("RING_FAILED", e.message, null)
                    }
                }
                "enableTheftMode" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            0
                        )
                        val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        activeRingtone?.stop()
                        activeRingtone = RingtoneManager.getRingtone(applicationContext, notification)
                        activeRingtone?.play()
                        result.success("Theft mode enabled successfully")
                    } catch (e: Exception) {
                        result.error("THEFT_MODE_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}