package com.protobridge.yike

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.util.AtomicFile
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.ceil

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
    private fun projectionTotal(p: JSONObject?): Int = p?.optInt("habitTotal", 0) ?: 0
    private fun objects(array: JSONArray): List<JSONObject> = (0 until array.length()).map { array.getJSONObject(it) }
    fun update(context: Context, manager: AppWidgetManager, id: Int, habits: Boolean, small: Boolean) {
        try { render(context, manager, id, habits, small) }
        catch (_: Exception) {
            val view = RemoteViews(context.packageName, R.layout.yike_widget)
            view.setTextViewText(R.id.widget_title, "一刻")
            view.setTextViewText(R.id.widget_footer, "打开一刻更新")
            view.setViewVisibility(R.id.widget_summary, View.GONE)
            view.removeAllViews(R.id.widget_rows)
            view.setOnClickPendingIntent(R.id.widget_card, pending(context, url(null, if (habits) "habits" else "focus")))
            manager.updateAppWidget(id, view)
        }
    }
    private fun render(context: Context, manager: AppWidgetManager, id: Int, habits: Boolean, small: Boolean) {
        val p = read(context)
        val now = System.currentTimeMillis()
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))
        val valid = p != null && (!habits || p.getString("date") == date)
        val options = manager.getAppWidgetOptions(id)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160)
        val compact = height < 188 && !small
        val large = !small && height >= 240
        val mode = p?.optString("appearance", "system") ?: "system"
        val systemDark = (context.resources.configuration.uiMode and 0x30) == 0x20
        val dark = mode == "dark" || (mode != "light" && systemDark)
        val palette = p?.optJSONObject("palette")
        fun color(key: String, fallback: Int): Int = try { Color.parseColor("#" + palette!!.getString((if (dark) "dark" else "light") + key)) } catch (_: Exception) { fallback }
        val foreground = color("Foreground", if (dark) Color.WHITE else Color.rgb(38, 37, 34))
        val accent = color("Accent", Color.rgb(210, 117, 54))
        val background = color("Background", if (dark) Color.rgb(29, 29, 31) else Color.rgb(248, 245, 238))
        val view = RemoteViews(context.packageName, R.layout.yike_widget)
        view.setInt(R.id.widget_background, "setColorFilter", background)
        view.setTextColor(R.id.widget_title, foreground)
        view.setTextColor(R.id.widget_summary, accent)
        view.setTextColor(R.id.widget_footer, foreground)
        view.setTextViewText(R.id.widget_title, if (habits) "一刻 · 今日打卡" else "一刻 · 专注")
        view.setViewVisibility(R.id.widget_title, View.VISIBLE)
        view.setViewVisibility(R.id.widget_summary, if (habits && valid) View.VISIBLE else View.GONE)
        view.setViewVisibility(R.id.widget_footer, View.VISIBLE)
        view.setViewVisibility(R.id.widget_progress, if (habits && valid && !small && projectionTotal(p) > 0) View.VISIBLE else View.GONE)
        if (habits && valid) view.setProgressBar(R.id.widget_progress, 100, (p!!.getInt("habitDone") * 100 / p.getInt("habitTotal").coerceAtLeast(1)), false)
        view.removeAllViews(R.id.widget_rows)
        view.setOnClickPendingIntent(R.id.widget_card, pending(context, url(p, if (habits) "habits" else "focus")))
        if (!valid) {
            view.setTextViewText(R.id.widget_footer, "打开一刻更新${if (habits) "今日打卡" else "专注进度"}")
            manager.updateAppWidget(id, view); return
        }
        val projection = p!!
        val updated = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(projection.getLong("generatedMs")))
        val unsaved = if (projection.getBoolean("unsaved")) " · 尚未保存" else ""
        view.setTextViewText(R.id.widget_footer, "数据于 $updated$unsaved")
        if (habits) {
            val done = projection.getInt("habitDone"); val total = projection.getInt("habitTotal")
            view.setTextViewText(R.id.widget_summary, "$done / $total")
            for (habit in objects(projection.getJSONArray("habits")).take(if (small) 1 else 3)) {
                val row = RemoteViews(context.packageName, R.layout.yike_widget_habit)
                val checked = habit.getBoolean("done")
                row.setTextViewText(R.id.habit_name, habit.getString("name"))
                val icon = when(habit.getString("icon")) {
                    "water" -> R.drawable.yike_habit_water; "book" -> R.drawable.yike_habit_book
                    "running" -> R.drawable.yike_habit_running; "moon" -> R.drawable.yike_habit_moon
                    "stretch" -> R.drawable.yike_habit_stretch; else -> R.drawable.yike_habit_leaf
                }
                row.setImageViewResource(R.id.habit_icon, icon)
                row.setInt(R.id.habit_icon, "setColorFilter", accent)
                row.setTextViewText(R.id.habit_mark, if (checked) "✓" else "○")
                row.setTextColor(R.id.habit_name, foreground); row.setTextColor(R.id.habit_mark, accent)
                row.setContentDescription(R.id.habit_row, "${habit.getString("name")}，今日${if (checked) "已完成" else "未完成"}")
                row.setOnClickPendingIntent(R.id.habit_row, pending(context, url(projection, "habits", habit = habit.getString("id"))))
                view.addView(R.id.widget_rows, row)
            }
            if (total == 0) view.setTextViewText(R.id.widget_footer, "打开一刻创建习惯")
            else if (done == total && !small) view.setTextViewText(R.id.widget_footer, "今天都完成了 · $updated$unsaved")
        } else {
            val timers = objects(projection.getJSONArray("timers"))
            val rows = timers.filter { it.getString("status") == "running" || it.getString("status") == "paused" }
            for (timer in rows) {
                val row = RemoteViews(context.packageName, R.layout.yike_widget_timer)
                val status = timer.getString("status"); val modeName = timer.getString("mode")
                val limit = timer.getLong("limitMs")
                val elapsed = (if (status == "running" && !timer.isNull("anchorMs")) now - timer.getLong("anchorMs") else timer.getLong("elapsedMs")).coerceIn(0, limit)
                val remaining = limit - elapsed
                val seconds = if (modeName == "stopwatch") elapsed / 1000 else ceil(remaining / 1000.0).toLong()
                val label = when(modeName) { "pomodoro" -> when(timer.getString("stage")) { "shortBreak" -> "短休息"; "longBreak" -> "长休息"; else -> "番茄钟" }; "stopwatch" -> "正计时"; else -> "倒计时" }
                val caption = if (status == "paused") "已暂停" else if (remaining == 0L) "已到点" else if (modeName == "pomodoro") "第 ${timer.getInt("round")} 轮" else if (modeName == "stopwatch") "${timer.getInt("laps")} 圈" else "进行中"
                row.setTextViewText(R.id.timer_name, label)
                row.setTextViewText(R.id.timer_time, String.format(Locale.US, "%02d:%02d", seconds / 60, seconds % 60))
                row.setTextViewText(R.id.timer_detail, caption)
                row.setTextColor(R.id.timer_name, foreground); row.setTextColor(R.id.timer_time, foreground); row.setTextColor(R.id.timer_detail, foreground)
                row.setViewVisibility(R.id.timer_detail, if (large || status == "paused") View.VISIBLE else View.GONE)
                row.setViewVisibility(R.id.timer_progress, if (large) View.VISIBLE else View.GONE)
                val amount = if (modeName == "stopwatch") elapsed else remaining
                row.setProgressBar(R.id.timer_progress, 100, ((amount * 100) / (timer.getLong("scaleSeconds") * 1000).coerceAtLeast(1)).toInt().coerceIn(0, 100), false)
                val action = if (status == "paused") "resume" else "pause"
                row.setImageViewResource(R.id.timer_action, if (status == "paused") android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause)
                row.setInt(R.id.timer_action, "setColorFilter", accent)
                row.setViewVisibility(R.id.timer_action, if (compact || (remaining == 0L && status == "running")) View.GONE else View.VISIBLE)
                row.setContentDescription(R.id.timer_action, "打开一刻${if (status == "paused") "继续" else "暂停"}$label")
                row.setOnClickPendingIntent(R.id.timer_body, pending(context, url(projection, "focus", timer)))
                row.setOnClickPendingIntent(R.id.timer_action, pending(context, url(projection, "focus", timer, action)))
                view.addView(R.id.widget_rows, row)
            }
            if (rows.isEmpty()) view.setTextViewText(R.id.widget_footer, if (timers.isEmpty()) "留一刻，专注此刻" else "本次计时已到点，打开查看")
            else if (large) view.setTextViewText(R.id.widget_footer, "今日已记录 ${projection.getInt("todaySeconds") / 60} 分钟 · $updated$unsaved")
        }
        manager.updateAppWidget(id, view)
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
