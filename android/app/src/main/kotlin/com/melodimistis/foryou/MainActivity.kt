package com.melodimistis.foryou

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaRoute2Info
import android.media.MediaRouter2
import android.media.RouteDiscoveryPreference
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private var routeCallback: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AudioFx.register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foryou/audio_output")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOutputSwitcher" -> result.success(showOutputSwitcher())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foryou/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> result.success(installApk(call.argument<String>("path")))
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(path: String?): Boolean {
        val file = path?.let { File(it) } ?: return false
        if (!file.isFile) return false
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
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
