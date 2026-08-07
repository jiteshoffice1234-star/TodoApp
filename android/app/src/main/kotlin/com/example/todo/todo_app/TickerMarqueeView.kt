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
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * Draws the pending-task ticker as a seamless horizontal marquee.
 *
 * The content string is a single "copy" of the ticker. It is drawn repeatedly
 * (once per copy-width, plus one copy before the visible area) so that when the
 * animation wraps by exactly one copy width the scroll looks unbroken — the same
 * trick used by the desktop PiP ticker.
 */
class TickerMarqueeView(context: Context) : View(context) {

    private val density = resources.displayMetrics.density

    private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00FFCC")
        textSize = 13f * density
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#E61A1A2E")
    }

    private val accentStripPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#00FFCC")
    }

    /** Accent color synced from the app theme; drives text + bottom strip. */
    fun setAccentColor(argb: Int) {
        textPaint.color = argb
        accentStripPaint.color = argb
        postInvalidateOnAnimation()
    }

    private var content: String = ""
    private var singleWidth: Float = 0f
    private var offset: Float = 0f
    private var animator: ValueAnimator? = null

    init {
        // Tap opens the app (brings it to front without relaunching).
        setOnClickListener {
            // Light haptic so the tap feels instant and deliberate.
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
        // Long-press stops the ticker.
        setOnLongClickListener {
            TickerOverlayService.stop(context)
            true
        }
        // Pause scrolling while touching, resume when released.
        setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> animator?.pause()
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> animator?.resume()
            }
            false
        }
    }

    /** Updates the ticker content, preserving the current scroll ratio (no jump). */
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

        // ~30s per full copy width, clamped so very short/long content still feels right.
        val speed = (singleWidth / 30f).coerceIn(20f, 120f)
        val distance = singleWidth
        val startValue = ratio * distance
        val durationMs = (distance / speed * 1000L).coerceAtLeast(1000L)

        val anim = ValueAnimator.ofFloat(startValue, startValue + distance).apply {
            this.duration = durationMs
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { a ->
                offset = -(a.animatedValue as Float)
                // Align redraws with the vsync frame — avoids a double redraw
                // per animation frame and keeps scrolling smooth next to the
                // Flutter UI (both share the main thread).
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
        val corner = 10f * density

        canvas.drawRoundRect(RectF(0f, 0f, w, h), corner, corner, bgPaint)

        // Accent strip along the bottom edge (inset so it respects the corners).
        canvas.drawRect(
            RectF(corner, h - 2f * density, w - corner, h),
            accentStripPaint
        )

        if (content.isEmpty() || singleWidth <= 0f) return

        val baseline = (h - textPaint.fontMetrics.ascent - textPaint.fontMetrics.descent) / 2f

        // One copy before the visible area covers negative offsets.
        canvas.drawText(content, offset - singleWidth, baseline, textPaint)

        // Then fill the rest of the viewport with period-W copies.
        var x = offset
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
