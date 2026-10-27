package com.protobridge.yike

import android.app.PendingIntent
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.AtomicFile
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.roundToInt

/** Display-only cache. No MMKV access, settlement or business state machine. */
object YikeWidgets {
    private fun cache(context: Context) = AtomicFile(File(context.filesDir, "yike-surfaces-v1.json"))
    private val providers = arrayOf(FocusWidget::class.java, FocusLargeWidget::class.java, HabitWidget::class.java, HabitMediumWidget::class.java)
    @Synchronized fun publish(context: Context, raw: String) {
        val projection = JSONObject(raw)
        require(projection.getInt("version") == 1)
        val file = cache(context)
        val output = file.startWrite()
        try { output.write(raw.toByteArray(Charsets.UTF_8)); file.finishWrite(output) }
        catch (error: Exception) { file.failWrite(output); throw error }
        updateAll(context)
    }
    @Synchronized fun clear(context: Context) {
        cache(context).delete()
        updateAll(context)
    }
    @Synchronized private fun read(context: Context): JSONObject? = try {
        val p = JSONObject(cache(context).openRead().bufferedReader().use { it.readText() })
        if (p.getInt("version") == 1 && p.getBoolean("readable") && p.getString("epoch").isNotEmpty() &&
            p.getJSONArray("timers").length() <= 3 && p.getJSONArray("habits").length() <= 3) p else null
    } catch (_: Exception) { null }
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) for (id in manager.getAppWidgetIds(ComponentName(context, provider))) {
            update(context, manager, id, provider == HabitWidget::class.java || provider == HabitMediumWidget::class.java,
                provider == HabitWidget::class.java)
        }
    }
    private fun url(p: JSONObject?, target: String, timer: JSONObject? = null, action: String = "view", habit: String? = null): Uri {
        val builder = Uri.Builder().scheme("yike").authority("surface")
            .appendQueryParameter("v", "1").appendQueryParameter("target", target).appendQueryParameter("action", action)
        if (timer != null) {
            builder.appendQueryParameter("mode", timer.getString("mode"))
            if (action != "view") {
                val status = timer.getString("status")
                builder.appendQueryParameter("session", timer.getString("session"))
                    .appendQueryParameter("stage", timer.getString("stage"))
                    .appendQueryParameter("expected", status)
                    .appendQueryParameter("epoch", p!!.getString("epoch"))
                    .appendQueryParameter("revision", p.getLong("revision").toString())
                    .appendQueryParameter("token", timer.getString("token"))
            }
        }
        if (habit != null) builder.appendQueryParameter("habit", habit)
        return builder.build()
    }
    private fun pending(context: Context, uri: Uri): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).setData(uri)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun objects(array: JSONArray): List<JSONObject> =
        (0 until array.length()).map { array.getJSONObject(it) }

    private fun dp(context: Context, value: Float): Int =
        (value * context.resources.displayMetrics.density).roundToInt()

    private fun mix(foreground: Int, background: Int, amount: Float): Int = Color.rgb(
        (Color.red(foreground) * amount + Color.red(background) * (1 - amount)).roundToInt(),
        (Color.green(foreground) * amount + Color.green(background) * (1 - amount)).roundToInt(),
        (Color.blue(foreground) * amount + Color.blue(background) * (1 - amount)).roundToInt(),
    )

    @Suppress("DEPRECATION")
    private fun sizes(options: Bundle, small: Boolean): List<SizeF> {
        if (Build.VERSION.SDK_INT >= 31) {
            val supplied = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                .orEmpty().filter { it.width.isFinite() && it.height.isFinite() && it.width > 0 && it.height > 0 }
                .distinct().take(16)
            if (supplied.isNotEmpty()) return supplied
        }
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, if (small) 110 else 250).coerceAtLeast(1)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).coerceAtLeast(1)
        val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth).coerceAtLeast(minWidth)
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight).coerceAtLeast(minHeight)
        // Legacy options describe portrait min-width/max-height and landscape max-width/min-height.
        return listOf(SizeF(minWidth.toFloat(), maxHeight.toFloat()), SizeF(maxWidth.toFloat(), minHeight.toFloat())).distinct()
    }

    fun update(context: Context, manager: AppWidgetManager, id: Int, habits: Boolean, small: Boolean) {
        val options = manager.getAppWidgetOptions(id)
        val p = read(context)
        val now = System.currentTimeMillis()
        try {
            manager.updateAppWidget(id, responsive(context, options, p, now, habits, small))
        } catch (error: Exception) {
            android.util.Log.e("YikeWidgets", "Widget rendering failed", error)
            // Build the same sized empty layout; never leave an old timer or fabricated habit count.
            manager.updateAppWidget(id, responsive(context, options, null, now, habits, small))
        }
    }

    private fun responsive(context: Context, options: Bundle, p: JSONObject?, now: Long, habits: Boolean, small: Boolean): RemoteViews {
        val sizes = sizes(options, small)
        val layouts = sizes.associateWith { renderSize(context, p, now, habits, small, it) }
        return if (Build.VERSION.SDK_INT >= 31) RemoteViews(layouts)
        else if (sizes.size == 1) layouts.getValue(sizes.first())
        else RemoteViews(layouts.getValue(sizes.last()), layouts.getValue(sizes.first()))
    }

    // Only presentation is projected here. This does not settle, save, or advance business state.
    private fun renderSize(context: Context, p: JSONObject?, now: Long, habits: Boolean, small: Boolean, size: SizeF): RemoteViews {
        val density = context.resources.displayMetrics.density
        val fontScale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        val hostPadding = AppWidgetHostView.getDefaultPaddingForWidget(context, ComponentName(context, FocusWidget::class.java), null)
        val cellGap = (hostPadding.left + hostPadding.right) / density
        // Match a square two-column card and a pair of those cards across four columns.
        // The standard host padding supplies the gutter; no launcher/package-specific pixels.
        val preferredHeight = if (small || size.height >= 230) size.width else (size.width - cellGap) / 2
        val inset = ((size.height - preferredHeight.coerceAtLeast(1f)) / 2).coerceAtLeast(0f)
        val cardHeight = size.height - 2 * inset
        val padding = if (size.width < 190 || cardHeight < 130) 10f else 14f
        val large = !small && cardHeight >= 230 && size.width >= 240
        val bodyHeight = (cardHeight - padding * 2 - 18 * fontScale - if (large || p?.optBoolean("unsaved") == true) 16 * fontScale else 0f).coerceAtLeast(1f)
        val mode = p?.optString("appearance", "system") ?: "system"
        val systemDark = (context.resources.configuration.uiMode and 0x30) == 0x20
        val dark = mode == "dark" || (mode != "light" && systemDark)
        val palette = p?.optJSONObject("palette")
        fun color(key: String, fallback: Int): Int = try {
            Color.parseColor("#" + palette!!.getString((if (dark) "dark" else "light") + key))
        } catch (_: Exception) { fallback }
        val foreground = color("Foreground", if (dark) Color.WHITE else Color.rgb(38, 37, 34))
        val accent = color("Accent", Color.rgb(210, 117, 54))
        val background = color("Background", if (dark) Color.rgb(29, 29, 31) else Color.rgb(248, 245, 238))
        val secondary = mix(foreground, background, .63f)
        val track = mix(foreground, background, .12f)
        val layout = if (!habits) R.layout.yike_widget else if (small) R.layout.yike_widget_habit_small else R.layout.yike_widget_habit_medium
        val view = RemoteViews(context.packageName, layout)
        view.setViewPadding(R.id.widget_root, 0, dp(context, inset), 0, dp(context, inset))
        view.setViewPadding(R.id.widget_content, dp(context, padding), dp(context, padding), dp(context, padding), dp(context, padding))
        view.setInt(R.id.widget_background, "setColorFilter", background)
        view.setTextViewText(R.id.widget_title, if (habits) "今日打卡" else "一刻 · 专注")
        view.setTextColor(R.id.widget_title, foreground)
        view.setTextColor(R.id.widget_updated, secondary)
        view.setTextColor(R.id.widget_footer, secondary)
        // Hosts may reapply the same layout. Reset visibility as well as text after an error state.
        view.setViewVisibility(R.id.widget_updated, View.VISIBLE)
        view.setViewVisibility(R.id.widget_footer, View.GONE)
        view.removeAllViews(R.id.widget_rows)
        view.setOnClickPendingIntent(R.id.widget_card, pending(context, url(p, if (habits) "habits" else "focus")))
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))
        val valid = p != null && (!habits || p.getString("date") == date)
        if (!valid) {
            view.setViewVisibility(R.id.widget_updated, View.GONE)
            if (habits) view.setViewVisibility(R.id.widget_habit_summary, View.GONE)
            addEmpty(context, view, if (habits) "今日待更新" else "专注待更新", "打开一刻更新${if (habits) "今日打卡" else "专注进度"}", foreground, secondary, small)
            return view
        }
        val projection = p
        val updated = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(projection.getLong("generatedMs")))
        view.setTextViewText(R.id.widget_updated, "$updated 更新")
        view.setContentDescription(R.id.widget_updated, "数据更新于 $updated；时间为展示快照，不连续走秒")
        val unsaved = projection.getBoolean("unsaved")
        view.setViewVisibility(R.id.widget_footer, if (unsaved || large && !habits) View.VISIBLE else View.GONE)
        view.setTextViewText(R.id.widget_footer, if (large && !habits) "今日已记录 ${projection.getInt("todaySeconds") / 60} 分钟${if (unsaved) " · 尚未保存" else ""}" else "尚未保存")
        if (habits) {
            val total = projection.getInt("habitTotal")
            val done = projection.getInt("habitDone")
            view.setViewVisibility(R.id.widget_habit_summary, if (total > 0) View.VISIBLE else View.GONE)
            if (total == 0) {
                addEmpty(context, view, "还没有习惯", "打开一刻创建习惯", foreground, secondary, small)
                return view
            }
            view.setTextViewText(R.id.widget_summary, "$done/$total")
            view.setTextColor(R.id.widget_summary, accent)
            view.setContentDescription(R.id.widget_summary, "今日已完成 $done 项，共 $total 项进行中习惯")
            if (!small) view.setTextColor(R.id.widget_summary_caption, secondary)
            if (small) {
                val showProgress = bodyHeight >= 96 * fontScale
                val habitHeight = if (showProgress) 40f else 32f
                view.setViewVisibility(R.id.widget_progress, if (showProgress) View.VISIBLE else View.GONE)
                view.setInt(R.id.widget_summary, "setHeight", dp(context, (bodyHeight - habitHeight - if (showProgress) 18 else 0).coerceIn(28f, 56f)))
            }
            progress(context, view, R.id.widget_progress, if (small) size.width - 2 * padding else 88f, done.toFloat() / total, accent, track)
            val entries = objects(projection.getJSONArray("habits")).take(if (small) 1 else 3)
            val rowHeight = if (small) (if (bodyHeight >= 96 * fontScale) 40f else 32f) else (bodyHeight / entries.size.coerceAtLeast(1)).coerceIn(24f, 38f)
            for (habit in entries) {
                val row = RemoteViews(context.packageName, R.layout.yike_widget_habit)
                val checked = habit.getBoolean("done")
                row.setInt(R.id.habit_row, "setMinimumHeight", dp(context, rowHeight))
                row.setInt(R.id.habit_name, "setMaxLines", if (small && bodyHeight >= 100 * fontScale) 2 else 1)
                row.setTextViewText(R.id.habit_name, habit.getString("name"))
                val icon = when (habit.getString("icon")) {
                    "water" -> R.drawable.yike_habit_water; "book" -> R.drawable.yike_habit_book
                    "running" -> R.drawable.yike_habit_running; "moon" -> R.drawable.yike_habit_moon
                    "stretch" -> R.drawable.yike_habit_stretch; else -> R.drawable.yike_habit_leaf
                }
                row.setImageViewResource(R.id.habit_icon, icon)
                row.setInt(R.id.habit_icon, "setColorFilter", accent)
                row.setTextViewText(R.id.habit_mark, if (checked) "✓" else "○")
                row.setTextColor(R.id.habit_name, foreground)
                row.setTextColor(R.id.habit_mark, if (checked) accent else secondary)
                row.setContentDescription(R.id.habit_row, "${habit.getString("name")}，今日${if (checked) "已完成" else "未完成"}")
                row.setOnClickPendingIntent(R.id.habit_row, pending(context, url(projection, "habits", habit = habit.getString("id"))))
                view.addView(R.id.widget_rows, row)
            }
        } else {
            val timers = objects(projection.getJSONArray("timers"))
            val rows = timers.filter { it.getString("status") in listOf("running", "paused") }
            if (rows.isEmpty()) {
                addEmpty(context, view, if (timers.isEmpty()) "留一刻，专注此刻" else "本次计时已完成", if (timers.isEmpty()) "打开一刻开始专注" else "打开一刻查看结果", foreground, secondary, false)
            }
            val rowHeight = (bodyHeight / rows.size.coerceAtLeast(1)).coerceAtMost(if (large) 88f else 58f)
            val hero = rows.size == 1 && bodyHeight >= 96 * fontScale && size.width >= 240
            for (timer in rows) {
                val status = timer.getString("status")
                val modeName = timer.getString("mode")
                val limit = timer.getLong("limitMs")
                val elapsed = (if (status == "running" && !timer.isNull("anchorMs")) now - timer.getLong("anchorMs") else timer.getLong("elapsedMs")).coerceIn(0, limit)
                val remaining = limit - elapsed
                val seconds = if (modeName == "stopwatch") elapsed / 1000 else ceil(remaining / 1000.0).toLong()
                val time = String.format(Locale.US, "%02d:%02d", seconds / 60, seconds % 60)
                val label = when (modeName) {
                    "pomodoro" -> when (timer.getString("stage")) { "shortBreak" -> "短休息"; "longBreak" -> "长休息"; else -> "番茄钟" }
                    "stopwatch" -> "正计时"; else -> "倒计时"
                }
                val state = if (status == "paused") "已暂停" else if (remaining == 0L) "已到点" else "进行中"
                val extra = if (modeName == "pomodoro") "第 ${timer.getInt("round")} 轮" else if (modeName == "stopwatch") "${timer.getInt("laps")} 圈" else ""
                val detail = if (state == "进行中" && extra.isNotEmpty()) extra else state
                val row = RemoteViews(context.packageName, if (hero) R.layout.yike_widget_timer_hero else R.layout.yike_widget_timer)
                val showDetail = hero || rowHeight >= 38 * fontScale
                val showProgress = hero || rowHeight >= 58 * fontScale
                val showAction = (hero || rowHeight >= 48) && size.width >= 270 && (status == "paused" || remaining > 0)
                row.setTextViewText(R.id.timer_name, if (showDetail) label else "$label · $state")
                row.setTextViewText(R.id.timer_time, time)
                row.setTextViewText(R.id.timer_detail, detail)
                row.setTextColor(R.id.timer_name, foreground)
                row.setTextColor(R.id.timer_time, if (state == "已到点") secondary else accent)
                row.setTextColor(R.id.timer_detail, secondary)
                row.setViewVisibility(R.id.timer_detail, if (showDetail) View.VISIBLE else View.GONE)
                row.setViewVisibility(R.id.timer_progress, if (showProgress) View.VISIBLE else View.GONE)
                if (!hero) {
                    row.setInt(R.id.timer_content, "setMinimumHeight", dp(context, rowHeight - if (large) 6 else 0))
                    row.setViewPadding(R.id.timer_row, 0, 0, 0, dp(context, if (large) 6f else 0f))
                    row.setViewPadding(R.id.timer_content, dp(context, if (large) 10f else 0f), 0, dp(context, if (large) 10f else 0f), 0)
                    row.setViewVisibility(R.id.timer_background, if (large) View.VISIBLE else View.GONE)
                    row.setInt(R.id.timer_background, "setColorFilter", mix(accent, background, .07f))
                    row.setInt(R.id.timer_time, "setHeight", dp(context, (rowHeight - 4).coerceIn(20f, 40f)))
                    row.setTextViewTextSize(R.id.timer_name, TypedValue.COMPLEX_UNIT_SP, if (showDetail) 13f else 12f)
                }
                if (showProgress) {
                    val amount = if (modeName == "stopwatch") elapsed else remaining
                    progress(context, row, R.id.timer_progress, size.width - 2 * padding, (amount.toFloat() / (timer.getLong("scaleSeconds") * 1000).coerceAtLeast(1)).coerceIn(0f, 1f), accent, track)
                }
                val action = if (status == "paused") "resume" else "pause"
                row.setImageViewResource(R.id.timer_action, if (status == "paused") android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause)
                row.setInt(R.id.timer_action, "setColorFilter", accent)
                row.setViewVisibility(R.id.timer_action, if (showAction) View.VISIBLE else View.GONE)
                row.setContentDescription(R.id.timer_body, "$label，$time，$state${if (extra.isEmpty()) "" else "，$extra"}")
                row.setContentDescription(R.id.timer_action, "打开一刻${if (status == "paused") "继续" else "暂停"}$label")
                row.setOnClickPendingIntent(R.id.timer_body, pending(context, url(projection, "focus", timer)))
                row.setOnClickPendingIntent(R.id.timer_action, pending(context, url(projection, "focus", timer, action)))
                view.addView(R.id.widget_rows, row)
            }
        }
        return view
    }

    private fun addEmpty(context: Context, view: RemoteViews, title: String, detail: String, foreground: Int, secondary: Int, small: Boolean) {
        val empty = RemoteViews(context.packageName, R.layout.yike_widget_empty)
        empty.setTextViewText(R.id.widget_empty_title, title)
        empty.setTextViewText(R.id.widget_empty_detail, detail)
        empty.setTextColor(R.id.widget_empty_title, foreground)
        empty.setTextColor(R.id.widget_empty_detail, secondary)
        if (small) empty.setTextViewTextSize(R.id.widget_empty_title, TypedValue.COMPLEX_UNIT_SP, 18f)
        view.addView(R.id.widget_rows, empty)
    }

    private fun progress(context: Context, view: RemoteViews, id: Int, width: Float, value: Float, accent: Int, track: Int) {
        // A static, themed bar works on API 24 too, without hidden tint APIs or a live clock.
        val height = dp(context, 4f).coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(dp(context, width).coerceIn(height, 1600), height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val radius = height / 2f
        paint.color = track
        canvas.drawRoundRect(0f, 0f, bitmap.width.toFloat(), height.toFloat(), radius, radius, paint)
        paint.color = accent
        if (value > 0) canvas.drawRoundRect(0f, 0f, bitmap.width * value.coerceIn(0f, 1f), height.toFloat(), radius, radius, paint)
        view.setImageViewBitmap(id, bitmap)
    }

}

open class YikeWidgetProvider(private val habits: Boolean = false, private val small: Boolean = false) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) YikeWidgets.update(context, manager, id, habits, small)
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        YikeWidgets.update(context, manager, id, habits, small)
    }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) YikeWidgets.updateAll(context)
    }
}
class FocusWidget : YikeWidgetProvider()
class FocusLargeWidget : YikeWidgetProvider()
class HabitWidget : YikeWidgetProvider(true, true)
class HabitMediumWidget : YikeWidgetProvider(true, false)
