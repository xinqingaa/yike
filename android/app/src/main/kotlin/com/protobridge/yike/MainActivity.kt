package com.protobridge.yike

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var surfaceChannel: MethodChannel? = null
    private var surfacesReady = false
    private val surfacePending = mutableListOf<String>()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        surfaceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yike/system_surfaces")
        surfaceChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "launch" -> {
                        surfacesReady = true
                        intent.data?.takeIf { it.scheme == "yike" && it.host == "surface" }?.let { surfacePending.add(it.toString()); intent.data = null }
                        result.success(surfacePending.toList()); surfacePending.clear()
                    }
                    "access" -> result.success(mapOf("widgets" to true, "activities" to false, "allowed" to false, "shared" to true))
                    "publish" -> { YikeWidgets.publish(this, call.arguments as String); result.success(null) }
                    "clear" -> { surfacePending.clear(); YikeWidgets.clear(this); result.success(null) }
                    "settings" -> { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName"))); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("surface_failed", "System surface operation failed", null) }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"yike/notifications")
        channel!!.setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "launch" -> { val raw = intent.getStringExtra("yike_payload"); intent.removeExtra("yike_payload"); result.success(raw) }
                    "schedule" -> { YikeNotifications.schedule(this,JSONObject(call.arguments as Map<*,*>)); result.success(null) }
                    "pending" -> result.success(YikeNotifications.pending(this))
                    "cancelPending" -> { YikeNotifications.cancel(this,call.arguments as Int); result.success(null) }
                    "removeDelivered" -> { YikeNotifications.removeDelivered(this,call.arguments as Int); result.success(null) }
                    "clear" -> { YikeNotifications.clear(this); result.success(null) }
                    "disabledChannels" -> result.success(YikeNotifications.disabledChannels(this))
                    "settings" -> { startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,packageName)); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("notification_failed","Notification operation failed",null) }
        }
    }
    override fun onResume() { super.onResume(); YikeNotifications.foreground = true }
    override fun onPause() { YikeNotifications.foreground = false; super.onPause() }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.takeIf { it.scheme == "yike" && it.host == "surface" }?.let {
            if (surfacesReady) surfaceChannel?.invokeMethod("open", it.toString()) else surfacePending.add(it.toString())
            intent.data = null
        }
        val raw = intent.getStringExtra("yike_payload")
        if(raw != null) { channel?.invokeMethod("tap",raw); intent.removeExtra("yike_payload") }
    }
}
