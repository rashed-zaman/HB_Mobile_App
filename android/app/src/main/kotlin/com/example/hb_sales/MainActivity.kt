package com.example.hb_sales

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.hb_sales/device_id",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOrCreateDeviceId" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    var id = prefs.getString(KEY_DEVICE_ID, null)
                    if (id.isNullOrEmpty()) {
                        id = UUID.randomUUID().toString()
                        prefs.edit().putString(KEY_DEVICE_ID, id).apply()
                    }
                    result.success(id)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "hb_sales_prefs"
        private const val KEY_DEVICE_ID = "device_id"
    }
}
