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
                    // as Int64 -> decoded as Long. Read as Any and normalize.
                    // Only apply when present — Dart omits the key until the
                    // theme reports in, and 0 (transparent black) would make the
                    // ticker text invisible instead of keeping the default green.
                    accentToInt(call.argument("accent"))?.let {
                        TickerOverlayService.setAccent(it)
                    }
                    result.success(true)
                }

                "updateTicker" -> {
                    TickerOverlayService.update(call.argument<String>("content") ?: "")
                    result.success(true)
                }

                "setTickerAccent" -> {
                    accentToInt(call.argument("accent"))?.let {
                        TickerOverlayService.setAccent(it)
                    }
                    result.success(true)
                }

                "stopTicker" -> {
                    TickerOverlayService.stop(this)
                    result.success(true)
                }

                "isTickerRunning" ->
                    result.success(TickerOverlayService.isRunning())

                // --- Ticker customization settings ---
                "setTickerFontSize" -> {
                    val size = (call.argument<Any>("size") as? Number)?.toFloat() ?: 15f
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    prefs.edit().putFloat(TickerOverlayService.KEY_FONT_SIZE, size).apply()
                    TickerOverlayService.getInstance()?.applySettings()
                    result.success(true)
                }

                "setTickerBgColor" -> {
                    val color = call.argument<Any>("color") as? Int ?: 0xFF1A1A2E.toInt()
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    prefs.edit().putInt(TickerOverlayService.KEY_BG_COLOR, color).apply()
                    TickerOverlayService.getInstance()?.applySettings()
                    result.success(true)
                }

                "setTickerBgAlpha" -> {
                    val alpha = (call.argument<Any>("alpha") as? Number)?.toFloat() ?: 0.9f
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    prefs.edit().putFloat(TickerOverlayService.KEY_BG_ALPHA, alpha).apply()
                    TickerOverlayService.getInstance()?.applySettings()
                    result.success(true)
                }

                "setTickerPosition" -> {
                    val isTop = call.argument<Boolean>("isTop") ?: true
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    prefs.edit().putBoolean(TickerOverlayService.KEY_POSITION_TOP, isTop).apply()
                    TickerOverlayService.getInstance()?.applySettings()
                    result.success(true)
                }

                "setTickerHeight" -> {
                    val height = (call.argument<Any>("height") as? Number)?.toFloat() ?: 64f
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    prefs.edit().putFloat(TickerOverlayService.KEY_HEIGHT, height).apply()
                    TickerOverlayService.getInstance()?.applySettings()
                    result.success(true)
                }

                "getTickerSettings" -> {
                    val prefs = getSharedPreferences("ticker_settings", MODE_PRIVATE)
                    result.success(mapOf(
                        "fontSize" to prefs.getFloat(TickerOverlayService.KEY_FONT_SIZE, 15f),
                        "accentColor" to prefs.getInt(TickerOverlayService.KEY_ACCENT_COLOR, 0xFF00FFCC.toInt()),
                        "bgColor" to prefs.getInt(TickerOverlayService.KEY_BG_COLOR, 0xFF1A1A2E.toInt()),
                        "bgAlpha" to prefs.getFloat(TickerOverlayService.KEY_BG_ALPHA, 0.9f),
                        "isTop" to prefs.getBoolean(TickerOverlayService.KEY_POSITION_TOP, true),
                        "height" to prefs.getFloat(TickerOverlayService.KEY_HEIGHT, 64f),
                    ))
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Normalizes the platform-channel accent value (Int, Long, or Double) to an ARGB Int, or null if absent. */
    private fun accentToInt(value: Any?): Int? {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            is Float -> value.toInt()
            else -> null
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
