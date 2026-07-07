package com.example.device_protection

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.device_protection/lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "lockDevice") {
                    lockDevice(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun lockDevice(result: MethodChannel.Result) {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val cn = ComponentName(this, DeviceAdminReceiver::class.java)

            if (dpm.isAdminActive(cn)) {
                dpm.lockNow()
                result.success(true)
                println("✅ Device locked successfully!")
            } else {
                // Request admin
                val intent = android.content.Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, cn)
                startActivity(intent)
                result.success(false)
                println("⚠️ Device Admin requested")
            }
        } catch (e: Exception) {
            result.error("LOCK_ERROR", e.message, null)
            println("❌ Lock error: ${e.message}")
        }
    }
}