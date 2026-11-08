package com.melodimistis.foryou

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaRoute2Info
import android.media.MediaRouter2
import android.media.RouteDiscoveryPreference
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var routeCallback: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foryou/audio_output")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOutputSwitcher" -> result.success(showOutputSwitcher())
                    else -> result.notImplemented()
                }
            }
    }

    private fun showOutputSwitcher(): String {
        if (Build.VERSION.SDK_INT >= 34) {
            val router = MediaRouter2.getInstance(this)
            if (routeCallback == null) {
                val callback = object : MediaRouter2.RouteCallback() {}
                router.registerRouteCallback(
                    mainExecutor,
                    callback,
                    RouteDiscoveryPreference.Builder(
                        listOf(MediaRoute2Info.FEATURE_LIVE_AUDIO),
                        false,
                    ).build(),
                )
                routeCallback = callback
            }
            if (router.showSystemOutputSwitcher()) return "switcher"
        }
        return try {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
            "bluetooth"
        } catch (e: ActivityNotFoundException) {
            "none"
        }
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 34) {
            (routeCallback as? MediaRouter2.RouteCallback)?.let {
                MediaRouter2.getInstance(this).unregisterRouteCallback(it)
            }
        }
        routeCallback = null
        super.onDestroy()
    }
}
