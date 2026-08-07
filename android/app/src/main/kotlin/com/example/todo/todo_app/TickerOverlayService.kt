package com.example.todo.todo_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
 * Communication:
 *  - Flutter pushes new content via [update] (and initial content via [start]).
 *  - [stop] removes the overlay and stops the service.
 */
class TickerOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "ticker_overlay"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP = "com.example.todo.todo_app.action.STOP_TICKER"

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
            // Only dispatch if the service is actually running — otherwise
            // startService() from a backgrounded app can throw on API 26+.
            if (activeInstance == null) return
            val intent = Intent(context, TickerOverlayService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }

        @JvmStatic
        fun isRunning(): Boolean = activeInstance != null

        @JvmStatic
        fun setAccent(argb: Int) {
            currentAccent = argb
            activeInstance?.applyAccent(argb)
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: TickerMarqueeView? = null

    override fun onBind(intent: Intent?): IBinder? = null

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
        // NOT_STICKY: if the process dies, don't resurrect a content-less bar;
        // the Flutter side restores the ticker on next launch/resume.
        return START_NOT_STICKY
    }

    fun setContent(content: String) {
        overlayView?.setItems(content)
    }

    fun applyAccent(argb: Int) {
        overlayView?.setAccentColor(argb)
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

        val heightPx = (46f * resources.displayMetrics.density).toInt()
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            heightPx,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP }

        try {
            wm.addView(view, params)
        } catch (e: Exception) {
            stopSelf()
            return
        }

        // Gentle fade-in so the bar never pops harshly over other apps.
        view.alpha = 0f
        view.animate().alpha(1f).setDuration(220).start()

        overlayView = view
        windowManager = wm
        activeInstance = this
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
            .setContentText("Floating task ticker active — tap to open")
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
