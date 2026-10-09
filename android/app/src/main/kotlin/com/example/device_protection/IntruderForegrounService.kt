package com.example.device_protection

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.hardware.camera2.*
import android.graphics.ImageFormat
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ImageReader
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.io.File
import java.io.ByteArrayOutputStream

class IntruderForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "intruder_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Security Service", NotificationManager.IMPORTANCE_NONE)
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
            
            val notification: Notification = Notification.Builder(this, channelId)
                .setContentTitle("Device Protection Active")
                .setContentText("Securing device...")
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .build()
            startForeground(101, notification)
        }

        try {
            FirebaseApp.initializeApp(this)
            capturePhoto()
        } catch (e: Exception) {
            Log.e("IntruderService", "Error: ${e.message}")
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun capturePhoto() {
        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        try {
            val cameraId = manager.cameraIdList.firstOrNull { id ->
                manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            } ?: manager.cameraIdList[0]

            val characteristics = manager.getCameraCharacteristics(cameraId)
            val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 270

            val handler = Handler(Looper.getMainLooper())
            val imageReader = ImageReader.newInstance(640, 480, ImageFormat.JPEG, 2)

            imageReader.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                if (image != null) {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    image.close()
                    reader.close()

                    handleCapturedImage(bytes, sensorOrientation)
                }
            }, handler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    val surface = imageReader.surface
                    
                    val previewRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                        addTarget(surface)
                        set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                    }

                    val stillRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                        addTarget(surface)
                        set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                    }

                    camera.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            try {
                                session.setRepeatingRequest(previewRequestBuilder.build(), null, handler)

                                handler.postDelayed({
                                    try {
                                        session.stopRepeating()
                                        session.capture(stillRequestBuilder.build(), null, handler)
                                    } catch (e: Exception) {
                                        Log.e("IntruderService", "Still capture failed: ${e.message}")
                                        camera.close()
                                        stopSelf()
                                    }
                                }, 2200)

                            } catch (e: Exception) {
                                Log.e("IntruderService", "Session execution failed: ${e.message}")
                                camera.close()
                                stopSelf()
                            }
                        }
                        override fun onConfigureFailed(session: CameraCaptureSession) {
                            camera.close()
                            stopSelf()
                        }
                    }, handler)
                }
                override fun onDisconnected(camera: CameraDevice) { camera.close(); stopSelf() }
                override fun onError(camera: CameraDevice, error: Int) { camera.close(); stopSelf() }
            }, handler)

        } catch (e: Exception) {
            Log.e("IntruderService", "Camera error: ${e.message}")
            stopSelf()
        }
    }

    private fun handleCapturedImage(bytes: ByteArray, sensorOrientation: Int) {
        try {
            // Safe decode with error validation
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            if (bitmap == null) {
                Log.e("IntruderService", "Failed to decode bitmap from byte array.")
                stopSelf()
                return
            }

            // Rotate and mirror horizontally for a natural front-camera selfie view
            val matrix = Matrix().apply {
                postRotate(sensorOrientation.toFloat())
                postScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
            }

            val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            
            val stream = ByteArrayOutputStream()
            rotatedBitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
            val correctedBytes = stream.toByteArray()

            val fileName = "intruder_${System.currentTimeMillis()}.jpg"
            val file = File(filesDir, fileName)
            file.writeBytes(correctedBytes)

            val base64Image = Base64.encodeToString(correctedBytes, Base64.DEFAULT)
            val auth = FirebaseAuth.getInstance()
            val userId = auth.currentUser?.uid ?: "anonymous_intruder"

            val data = hashMapOf(
                "userId" to userId,
                "localPath" to file.absolutePath,
                "imageBase64" to base64Image,
                "timestamp" to com.google.firebase.firestore.FieldValue.serverTimestamp()
            )

            FirebaseFirestore.getInstance().collection("intruder_photos").add(data)
                .addOnSuccessListener {
                    Log.d("IntruderService", "Uploaded to Firestore successfully!")
                    stopSelf()
                }
                .addOnFailureListener { e ->
                    Log.e("IntruderService", "Firestore upload failed: ${e.message}")
                    stopSelf()
                }
        } catch (e: Exception) {
            Log.e("IntruderService", "Error handling image: ${e.message}")
            stopSelf()
        }
    }
}