package dev.spydon.sun_tracker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.atan
import kotlin.math.max

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "sun_tracker/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "cameraFieldOfView" -> {
                    val cameraId = call.argument<String>("cameraId")
                    result.success(cameraId?.let { longSideFieldOfView(it) })
                }
                "hasCameraPermission" -> result.success(
                    checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun longSideFieldOfView(cameraId: String): Double? {
        return try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val characteristics = manager.getCameraCharacteristics(cameraId)
            val physicalSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                ?: return null
            val focalLength = characteristics
                .get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                ?.firstOrNull()
                ?: return null
            val pixelArray = characteristics.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
            val activeArray = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            var width = physicalSize.width.toDouble()
            var height = physicalSize.height.toDouble()
            if (pixelArray != null && activeArray != null && pixelArray.width > 0 && pixelArray.height > 0) {
                width *= activeArray.width().toDouble() / pixelArray.width
                height *= activeArray.height().toDouble() / pixelArray.height
            }
            val longSide = max(width, height)
            Math.toDegrees(2 * atan(longSide / (2 * focalLength)))
        } catch (exception: Exception) {
            null
        }
    }
}
