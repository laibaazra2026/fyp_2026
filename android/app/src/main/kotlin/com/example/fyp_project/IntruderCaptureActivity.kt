package com.example.device_protection

import android.app.Activity
import android.os.Bundle
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

class IntruderCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val db = FirebaseFirestore.getInstance()
        val currentUser = FirebaseAuth.getInstance().currentUser
        val userId = currentUser?.uid ?: "anonymous_user"
        val userEmail = currentUser?.email ?: "unknown@example.com"

        val intruderData = hashMapOf(
            "userId" to userId,
            "userEmail" to userEmail,
            "status" to "Wrong password attempt detected",
            "date" to System.currentTimeMillis()
        )

        db.collection("intruder_photos")
            .add(intruderData)
            .addOnSuccessListener {
                Log.d("IntruderCapture", "Intruder log successfully recorded!")
                finish()
            }
            .addOnFailureListener { e: Exception ->
                Log.e("IntruderCapture", "Error recording intruder", e)
                finish()
            }
    }
}