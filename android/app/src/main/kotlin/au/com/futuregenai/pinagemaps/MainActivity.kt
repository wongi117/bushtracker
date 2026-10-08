package au.com.futuregenai.pinagemaps

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The AR overlay has to know how much of the world the camera image
        // covers. It used to assume 65 degrees across, which on this phone's
        // camera drew every wall and pin at about half its real height. The
        // Flutter camera plugin does not expose the optics, so they are read
        // here, from the camera the plugin opens: the first back camera.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pinage/camera_optics")
            .setMethodCallHandler { call, result ->
                if (call.method != "backCamera") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                    val id = manager.cameraIdList.firstOrNull { cid ->
                        manager.getCameraCharacteristics(cid)
                            .get(CameraCharacteristics.LENS_FACING) ==
                            CameraCharacteristics.LENS_FACING_BACK
                    }
                    if (id == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val c = manager.getCameraCharacteristics(id)
                    val physical = c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                    val focal = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    val pixels = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                    val active = c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
                    if (physical == null || focal == null || focal.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(
                        mapOf(
                            "cameraId" to id,
                            "sensorWidthMm" to physical.width.toDouble(),
                            "sensorHeightMm" to physical.height.toDouble(),
                            "focalLengthMm" to focal[0].toDouble(),
                            "pixelArrayWidth" to (pixels?.width ?: 0),
                            "pixelArrayHeight" to (pixels?.height ?: 0),
                            "activeWidth" to (active?.width() ?: 0),
                            "activeHeight" to (active?.height() ?: 0),
                        )
                    )
                } catch (e: Exception) {
                    result.error("optics", e.message, null)
                }
            }
    }
}
