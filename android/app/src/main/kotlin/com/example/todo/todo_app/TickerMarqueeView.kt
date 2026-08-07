package com.example.todo.todo_app

import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.PopupMenu

/**
 * Draws the pending-task ticker as a seamless horizontal marquee.
 *
 * Supports full customization:
 *  - Draggable (long-press + drag to reposition)
 *  - Font size adjustable (tap popup menu)
 *  - Background color & opacity
 *  - Accent color from app theme
 *  - Position (top/bottom)
 */
class TickerMarqueeView(context: Context) : View(context) {

    private val density = resources.displayMetrics.density

    // --- Settings (loaded from SharedPreferences) ---
    var fontSizeSp: Float = 15f
        set(value) { field = value; textPaint.textSize = value * density; requestLayout(); invalidate() }

    var bgColor: Int = Color.parseColor("#E61A1A2E")
        set(value) { field = value; bgPaint.color = value; invalidate() }

    var bgAlpha: Float = 0.9f
        set(value) {
            field = value
            val a = (value * 255).toInt().coerceIn(0, 255)
            bgPaint.color = Color.argb(a, Color.red(bgColor), Color.green(bgColor), Color.blue(bgColor))
            invalidate()
        }

    var accentColor: Int = Color.parseColor("#00FFCC")
        set(value) {
            field = value
            textPaint.color = value
            accentStripPaint.color = value
            iconPaint.color = blendAlpha(value, 0.7f)
            invalidate()
        }

    // --- Paints ---
    private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = accentColor
        textSize = fontSizeSp * density
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = bgColor
    }

    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#40000000")
        maskFilter = android.graphics.BlurMaskFilter(6f * density, android.graphics.BlurMaskFilter.Blur.NORMAL)
    }

    private val accentStripPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = accentColor
    }

    private val iconPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 14f * density
        typeface = Typeface.DEFAULT
    }

    // --- Inner padding ---
    private val padStart = 12f * density
    private val padEnd = 12f * density

    // --- Marquee state ---
    private var content: String = ""
    private var singleWidth: Float = 0f
    private var offset: Float = 0f
    private var animator: ValueAnimator? = null

    // --- Drag state ---
    private var isDragging = false
    private var dragStartY = 0f
    private var initialParamY = 0
    private var longPressTriggered = false

    /** Callback when user wants to reposition the overlay. */
    var onReposition: ((newY: Int) -> Unit)? = null

    /** Callback when settings popup action occurs. */
    var onSettingsAction: ((action: String) -> Unit)? = null

    private fun blendAlpha(color: Int, factor: Float): Int {
        val a = ((Color.alpha(color) * factor).toInt()).coerceIn(0, 255)
        return Color.argb(a, Color.red(color), Color.green(color), Color.blue(color))
    }

    init {
        // Tap opens the app
        setOnClickListener {
            if (isDragging) return@setOnClickListener
            performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                context.startActivity(launch)
            }
        }

        // Long-press shows popup menu, then supports drag
        setOnLongClickListener {
            if (!isDragging) {
                showPopupMenu()
            }
            true
        }

        // Touch handling for drag
        setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    longPressTriggered = false
                    dragStartY = event.rawY
                    initialParamY = 0 // Will be set on drag start
                    animator?.pause()
                    false // Let click/long-press handlers work
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.rawY - dragStartY
                    if (Math.abs(dy) > 10 * density && !longPressTriggered) {
                        // Started moving — this is a drag, suppress click
                        isDragging = true
                        longPressTriggered = true
                        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                    }
                    if (isDragging) {
                        val newY = (initialParamY + dy.toInt())
                            .coerceIn(0, resources.displayMetrics.heightPixels - height)
                        onReposition?.invoke(newY)
                        true
                    } else {
                        false
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (!isDragging) {
                        animator?.resume()
                    }
                    isDragging = false
                    false
                }
                else -> false
            }
        }
    }

    /** Call this to set the initial WindowManager y-position for drag calculations. */
    fun setInitialY(y: Int) {
        initialParamY = y
    }

    private fun showPopupMenu() {
        val popup = PopupMenu(context, this, Gravity.END)
        popup.menu.add(0, 1, 0, "A+  Bigger text")
        popup.menu.add(0, 2, 1, "A-  Smaller text")
        popup.menu.add(0, 3, 2, "🎨  Accent color")
        popup.menu.add(0, 4, 3, "⬛  Background color")
        popup.menu.add(0, 5, 4, "↕  Position (top/bottom)")
        popup.menu.add(0, 6, 5, "🎚  Opacity")
        popup.menu.add(0, 7, 6, "🛑  Stop ticker")

        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1 -> onSettingsAction?.invoke("font_up")
                2 -> onSettingsAction?.invoke("font_down")
                3 -> onSettingsAction?.invoke("accent_color")
                4 -> onSettingsAction?.invoke("bg_color")
                5 -> onSettingsAction?.invoke("position")
                6 -> onSettingsAction?.invoke("opacity")
                7 -> {
                    TickerOverlayService.stop(context)
                }
            }
            true
        }
        popup.show()
    }

    /** Updates the ticker content, preserving the current scroll ratio. */
    fun setItems(items: String) {
        val normalized = items ?: ""
        if (normalized == content && animator != null) return

        val ratio = if (singleWidth > 0) {
            ((-offset / singleWidth).toDouble().coerceIn(0.0, 0.99)).toFloat()
        } else {
            0f
        }

        content = normalized
        singleWidth = textPaint.measureText(content)
        animator?.cancel()
        animator = null

        if (content.isEmpty()) {
            offset = 0f
            invalidate()
            return
        }

        val speed = (singleWidth / 30f).coerceIn(20f, 120f)
        val distance = singleWidth
        val startValue = ratio * distance
        val durationMs = (distance / speed * 1000).toLong().coerceAtLeast(1000L)

        val anim = ValueAnimator.ofFloat(startValue, startValue + distance).apply {
            this.duration = durationMs
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { a ->
                offset = -(a.animatedValue as Float)
                postInvalidateOnAnimation()
            }
            start()
        }
        animator = anim
        offset = -startValue
        invalidate()
    }

    fun stopAnimation() {
        animator?.cancel()
        animator = null
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        val corner = 12f * density

        // Drop shadow
        canvas.drawRoundRect(RectF(0f, 2f * density, w, h), corner, corner, shadowPaint)

        // Main background
        canvas.drawRoundRect(RectF(0f, 0f, w, h), corner, corner, bgPaint)

        // Accent strip along bottom (3dp)
        canvas.drawRect(RectF(corner, h - 3f * density, w - corner, h), accentStripPaint)

        // Icon on left
        val iconY = (h + iconPaint.textSize * 0.35f) / 2f
        canvas.drawText("\uD83D\uDCCC", padStart * 0.3f, iconY, iconPaint)

        if (content.isEmpty() || singleWidth <= 0f) return

        val baseline = (h - textPaint.fontMetrics.ascent - textPaint.fontMetrics.descent) / 2f
        val scrollStart = padStart + iconPaint.textSize + padStart * 0.5f

        // One copy before visible area
        canvas.drawText(content, offset - singleWidth + scrollStart, baseline, textPaint)

        // Fill rest of viewport
        var x = offset + scrollStart
        while (x < w) {
            canvas.drawText(content, x, baseline, textPaint)
            x += singleWidth
        }
    }

    override fun onDetachedFromWindow() {
        stopAnimation()
        super.onDetachedFromWindow()
    }
}
