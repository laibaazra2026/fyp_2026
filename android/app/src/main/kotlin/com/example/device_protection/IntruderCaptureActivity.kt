package com.example.device_protection

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

class IntruderCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request Camera Permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 100)
            return
        }

        // Log Intruder Attempt to Firebase (Syncs to Web Portal & Admin App)
        val db = FirebaseFirestore.getInstance()
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userId = currentUser?.uid ?: "anonymous_user"
        val userEmail = currentUser?.email ?: "unknown@example.com"

        val intruderData = hashMapOf(
            "userId" to userId,
            "userEmail" to userEmail,
            "status" to "Wrong password attempt - Intruder Captured",
            "date" to System.currentTimeMillis()
        )

        db.collection("intruder_photos")
            .add(intruderData)
            .addOnSuccessListener {
                Log.d("IntruderCapture", "Success: Logged to Firebase for Web & Admin App!")
                finish()
            }
            .addOnFailureListener { e ->
                Log.e("IntruderCapture", "Error logging intruder", e)
                finish()
            }
    }
}