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
                "setDeviceId" -> {
                    val id = call.arguments as? String
                    if (id.isNullOrBlank()) {
                        result.error("INVALID_ID", "Device id is required", null)
                        return@setMethodCallHandler
                    }
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putString(KEY_DEVICE_ID, id.trim())
                        .apply()
                    result.success(null)
                }
                "getBoundDeviceData" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getString(KEY_BOUND_DEVICE_DATA, null))
                }
                "setBoundDeviceData" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrBlank()) {
                        result.error("INVALID_DATA", "Bound device data is required", null)
                        return@setMethodCallHandler
                    }
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putString(KEY_BOUND_DEVICE_DATA, json)
                        .apply()
                    result.success(null)
                }
                "clearBoundDeviceData" -> {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .remove(KEY_BOUND_DEVICE_DATA)
                        .apply()
                    result.success(null)
                }
                "clearDeviceId" -> {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .remove(KEY_DEVICE_ID)
                        .apply()
                    result.success(null)
                }
                "getLoginPayload" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getString(KEY_LOGIN_PAYLOAD, null))
                }
                "setLoginPayload" -> {
                    val json = call.arguments as? String
                    if (json.isNullOrBlank()) {
                        result.error("INVALID_DATA", "Login payload is required", null)
                        return@setMethodCallHandler
                    }
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .putString(KEY_LOGIN_PAYLOAD, json)
                        .apply()
                    result.success(null)
                }
                "clearLoginPayload" -> {
                    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit()
                        .remove(KEY_LOGIN_PAYLOAD)
                        .apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "hb_sales_prefs"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_BOUND_DEVICE_DATA = "bound_device_data"
        private const val KEY_LOGIN_PAYLOAD = "login_payload"
    }
}
