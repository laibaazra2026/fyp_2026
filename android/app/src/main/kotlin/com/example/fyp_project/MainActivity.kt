package com.example.device_protection

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
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
                    "capturePhoto" -> {
                        result.success(true)
                    }
                    "lockNow" -> {
                        val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)
                        
                        if (devicePolicyManager.isAdminActive(adminComponent)) {
                            devicePolicyManager.lockNow()
                            result.success(true)
                        } else {
                            result.error("NOT_ADMIN", "Device admin not active", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}