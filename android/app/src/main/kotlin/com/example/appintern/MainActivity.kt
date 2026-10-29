package com.example.appintern

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val memoryChannel = "com.example.appintern/device_memory"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, memoryChannel).setMethodCallHandler { call, result ->
            if (call.method == "getMemoryInfo") {
                try {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    if (activityManager != null) {
                        val memoryInfo = ActivityManager.MemoryInfo()
                        activityManager.getMemoryInfo(memoryInfo)

                        val data = mapOf(
                            "availMemMb" to (memoryInfo.availMem / (1024 * 1024)),
                            "totalMemMb" to (memoryInfo.totalMem / (1024 * 1024)),
                            "isLowMemory" to memoryInfo.lowMemory,
                            "thresholdMb" to (memoryInfo.threshold / (1024 * 1024))
                        )
                        result.success(data)
                    } else {
                        result.error("UNAVAILABLE", "ActivityManager not available", null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
