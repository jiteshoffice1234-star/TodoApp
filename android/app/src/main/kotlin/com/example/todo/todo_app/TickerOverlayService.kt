package com.example.todo.todo_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import androidx.core.content.ContextCompat

/**
 * Foreground service that keeps the floating task ticker visible on top of
 * every app, even when the Todo App is backgrounded.
 *
 * Full customization:
 *  - Draggable (long-press + drag to reposition)
 *  - Font size, accent color, background color, opacity
 *  - Position (top/bottom)
 *  - All settings persisted in SharedPreferences
 */
class TickerOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "ticker_overlay"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP = "com.example.todo.todo_app.action.STOP_TICKER"
        private const val PREFS_NAME = "ticker_settings"

        // SharedPreferences keys
        const val KEY_FONT_SIZE = "ticker_font_size"
        const val KEY_ACCENT_COLOR = "ticker_accent_color"
        const val KEY_BG_COLOR = "ticker_bg_color"
        const val KEY_BG_ALPHA = "ticker_bg_alpha"
        const val KEY_POSITION_TOP = "ticker_position_top"
        const val KEY_HEIGHT = "ticker_height"

        @Volatile private var activeInstance: TickerOverlayService? = null
        @Volatile private var currentContent: String = ""
        @Volatile private var currentAccent: Int? = null

        @JvmStatic
        fun start(context: Context, content: String) {
            currentContent = content
            val intent = Intent(context, TickerOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        @JvmStatic
        fun update(content: String) {
            currentContent = content
            activeInstance?.setContent(content)
        }

        @JvmStatic
        fun stop(context: Context) {
            if (activeInstance == null) return
            val intent = Intent(context, TickerOverlayService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }

        @JvmStatic
        fun isRunning(): Boolean = activeInstance != null

        @JvmStatic
        fun setAccent(argb: Int) {
            currentAccent = argb
            // Also persist as default accent
            val prefs = getInstance()?.getPrefs() ?: return
            prefs.edit().putInt(KEY_ACCENT_COLOR, argb).apply()
            activeInstance?.applyAccent(argb)
        }

        fun getInstance(): TickerOverlayService? = activeInstance
    }

    private var windowManager: WindowManager? = null
    private var overlayView: TickerMarqueeView? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private lateinit var prefs: SharedPreferences

    fun getPrefs(): SharedPreferences = prefs

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTicker()
            return START_NOT_STICKY
        }
        if (!canDrawOverlays()) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundCompat()
        showOverlay()
        setContent(currentContent)
        currentAccent?.let { applyAccent(it) }
        return START_NOT_STICKY
    }

    fun setContent(content: String) {
        overlayView?.setItems(content)
    }

    fun applyAccent(argb: Int) {
        overlayView?.accentColor = argb
    }

    fun applySettings() {
        val view = overlayView ?: return
        val params = overlayParams ?: return
        val wm = windowManager ?: return

        // Apply font size
        view.fontSizeSp = prefs.getFloat(KEY_FONT_SIZE, 15f)

        // Apply accent color
        val accent = prefs.getInt(KEY_ACCENT_COLOR, 0xFF00FFCC.toInt())
        view.accentColor = accent

        // Apply background color
        val bg = prefs.getInt(KEY_BG_COLOR, 0xFF1A1A2E.toInt())
        view.bgColor = bg

        // Apply opacity
        val alpha = prefs.getFloat(KEY_BG_ALPHA, 0.9f)
        view.bgAlpha = alpha

        // Apply position
        val isTop = prefs.getBoolean(KEY_POSITION_TOP, true)
        params.gravity = if (isTop) Gravity.TOP else Gravity.BOTTOM

        // Apply height
        val heightDp = prefs.getFloat(KEY_HEIGHT, 64f)
        params.height = (heightDp * resources.displayMetrics.density).toInt()

        // Update layout
        try {
            wm.updateViewLayout(overlayView, params)
        } catch (_: Exception) {}
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)

    private fun showOverlay() {
        if (overlayView != null) return

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val view = TickerMarqueeView(this)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY
        }

        // Read settings
        val heightDp = prefs.getFloat(KEY_HEIGHT, 64f)
        val heightPx = (heightDp * resources.displayMetrics.density).toInt()
        val isTop = prefs.getBoolean(KEY_POSITION_TOP, true)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            heightPx,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = if (isTop) Gravity.TOP else Gravity.BOTTOM
        }

        // Apply saved settings to view
        view.fontSizeSp = prefs.getFloat(KEY_FONT_SIZE, 15f)
        view.accentColor = prefs.getInt(KEY_ACCENT_COLOR, 0xFF00FFCC.toInt())
        view.bgColor = prefs.getInt(KEY_BG_COLOR, 0xFF1A1A2E.toInt())
        view.bgAlpha = prefs.getFloat(KEY_BG_ALPHA, 0.9f)

        // Set initial Y for drag calculations
        view.setInitialY(params.y)

        // Reposition callback
        view.onReposition = { newY ->
            params.y = newY
            params.gravity = Gravity.TOP // When dragged, always use top gravity with explicit Y
            try {
                wm.updateViewLayout(view, params)
            } catch (_: Exception) {}
            // Save position
            prefs.edit().putInt("ticker_y", newY).apply()
        }

        // Settings popup callback
        view.onSettingsAction = { action ->
            handleSettingsAction(action)
        }

        try {
            wm.addView(view, params)
        } catch (e: Exception) {
            stopSelf()
            return
        }

        // Fade-in
        view.alpha = 0f
        view.animate().alpha(1f).setDuration(220).start()

        overlayView = view
        overlayParams = params
        windowManager = wm
        activeInstance = this
    }

    private fun handleSettingsAction(action: String) {
        val editor = prefs.edit()
        when (action) {
            "font_up" -> {
                val current = prefs.getFloat(KEY_FONT_SIZE, 15f)
                val new = (current + 2f).coerceAtMost(30f)
                editor.putFloat(KEY_FONT_SIZE, new)
                editor.apply()
                applySettings()
            }
            "font_down" -> {
                val current = prefs.getFloat(KEY_FONT_SIZE, 15f)
                val new = (current - 2f).coerceAtLeast(8f)
                editor.putFloat(KEY_FONT_SIZE, new)
                editor.apply()
                applySettings()
            }
            "accent_color" -> {
                // Cycle through preset colors
                val presets = intArrayOf(
                    0xFF00FFCC.toInt(),
                    0xFF1976D2.toInt(),
                    0xFF388E3C.toInt(),
                    0xFFD32F2F.toInt(),
                    0xFFFF9800.toInt(),
                    0xFF7B1FA2.toInt(),
                )
                val current = prefs.getInt(KEY_ACCENT_COLOR, 0xFF00FFCC.toInt())
                val idx = presets.indexOf(current)
                val next = if (idx < 0) 0 else (idx + 1) % presets.size
                editor.putInt(KEY_ACCENT_COLOR, presets[next])
                editor.apply()
                applySettings()
            }
            "bg_color" -> {
                // Cycle through preset backgrounds
                val presets = intArrayOf(
                    0xFF1A1A2E.toInt(),
                    0xFF0D1117.toInt(),
                    0xFF1E1E2E.toInt(),
                    0xFF2D2D3D.toInt(),
                    0xFF000000.toInt(),
                    0xFF1A1A1A.toInt(),
                )
                val current = prefs.getInt(KEY_BG_COLOR, 0xFF1A1A2E.toInt())
                val idx = presets.indexOf(current)
                val next = if (idx < 0) 0 else (idx + 1) % presets.size
                editor.putInt(KEY_BG_COLOR, presets[next])
                editor.apply()
                applySettings()
            }
            "position" -> {
                val current = prefs.getBoolean(KEY_POSITION_TOP, true)
                editor.putBoolean(KEY_POSITION_TOP, !current)
                editor.apply()
                applySettings()
            }
            "opacity" -> {
                // Cycle: 0.5 -> 0.7 -> 0.9 -> 1.0 -> 0.5
                val presets = floatArrayOf(0.5f, 0.7f, 0.9f, 1.0f)
                val current = prefs.getFloat(KEY_BG_ALPHA, 0.9f)
                val idx = presets.indexOfFirst { Math.abs(it - current) < 0.01f }
                val next = if (idx < 0) 2 else (idx + 1) % presets.size
                editor.putFloat(KEY_BG_ALPHA, presets[next])
                editor.apply()
                applySettings()
            }
        }
    }

    private fun removeOverlay() {
        val wm = windowManager
        val view = overlayView
        if (view != null && wm != null) {
            try {
                wm.removeView(view)
            } catch (_: Exception) {
            }
        }
        overlayView = null
        overlayParams = null
        windowManager = null
        activeInstance = null
    }

    private fun stopTicker() {
        removeOverlay()
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startForegroundCompat() {
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Floating Task Ticker",
                NotificationManager.IMPORTANCE_LOW
            )
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        val openPi = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = Intent(this, TickerOverlayService::class.java).setAction(ACTION_STOP)
        val stopPi = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val icon = R.mipmap.ic_launcher
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        builder
            .setContentTitle("Todo Ticker")
            .setContentText("Floating task ticker active - tap to open, long-press for settings")
            .setSmallIcon(icon)
            .setOngoing(true)
            .setContentIntent(openPi)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            builder.addAction(
                Notification.Action.Builder(
                    android.graphics.drawable.Icon.createWithResource(this, icon),
                    "Stop",
                    stopPi
                ).build()
            )
        } else {
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPi)
        }

        return builder.build()
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }
}
