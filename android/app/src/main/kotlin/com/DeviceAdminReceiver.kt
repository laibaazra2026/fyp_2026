package com.example.fyp_mobile_app_and_web_portal 

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MyDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d("IntruderDetection", "Wrong password or lock attempt detected!")
        
    }
}