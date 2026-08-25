package com.example.device_protection

import android.app.Activity
import android.os.Bundle
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

class IntruderCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val db = FirebaseFirestore.instance
        val userId = FirebaseAuth.instance.currentUser?.uid ?: "test_user"

        val data = hashMapOf(
            "userId" to userId,
            "timestamp" to com.google.firebase.Timestamp.now(),
            "status" to "Wrong password entered - test capture"
        )

        db.collection("intruder_photos").add(data)
            .addOnSuccessListener {
                Log.d("IntruderCapture", "Test log recorded successfully!")
                finish()
            }
            .addOnFailureListener {
                finish()
            }
    }
}