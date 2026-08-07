package com.example.todo.todo_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "todo_app/ticker_overlay"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" ->
                    result.success(canDrawOverlays())

                "requestOverlayPermission" -> {
                    openOverlaySettings()
                    result.success(true)
                }

                "startTicker" -> {
                    TickerOverlayService.start(this, call.argument<String>("content") ?: "")
                    // ARGB values exceed 32-bit int range, so Dart encodes them
                    // as Int64 -> decoded as Long. Read as Number to cover both.
                    call.argument<Number>("accent")?.let {
                        TickerOverlayService.setAccent(it.intValue())
                    }
                    result.success(true)
                }

                "updateTicker" -> {
                    TickerOverlayService.update(call.argument<String>("content") ?: "")
                    result.success(true)
                }

                "setTickerAccent" -> {
                    call.argument<Number>("accent")?.let {
                        TickerOverlayService.setAccent(it.intValue())
                    }
                    result.success(true)
                }

                "stopTicker" -> {
                    TickerOverlayService.stop(this)
                    result.success(true)
                }

                "isTickerRunning" ->
                    result.success(TickerOverlayService.isRunning())

                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
    }
}
