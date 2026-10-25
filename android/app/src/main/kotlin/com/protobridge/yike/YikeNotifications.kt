package com.protobridge.yike

import android.app.*
import android.content.*
import android.os.Build
import android.provider.Settings
import android.net.Uri
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Calendar

/** Native alarms outlive Dart. Foreground suppression happens before notify(). */
object YikeNotifications {
    @Volatile var foreground = false
    private fun prefs(c: Context) = c.getSharedPreferences("yike_notifications", Context.MODE_PRIVATE)
    private fun alarm(c: Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun manager(c: Context) = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun intent(c: Context, id: Int) = PendingIntent.getBroadcast(c, id,
        Intent(c, YikeNotificationReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun pending(c: Context) = prefs(c).all.keys.mapNotNull { it.toIntOrNull() }
    fun schedule(c: Context, j: JSONObject) {
        val id = j.getInt("id")
        // Commit first: a crash cannot leave an unowned live alarm.
        if (!prefs(c).edit().putString(id.toString(), j.toString()).commit()) error("Alarm metadata save failed")
        val at = j.getLong("at")
        val exact = j.optBoolean("exact") && (Build.VERSION.SDK_INT < 31 || alarm(c).canScheduleExactAlarms())
        if (exact) alarm(c).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(c,id))
        else alarm(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(c,id))
    }
    fun cancel(c: Context, id: Int) {
        alarm(c).cancel(intent(c,id))
        if (!prefs(c).edit().remove(id.toString()).commit()) error("Alarm metadata remove failed")
    }
    fun removeDelivered(c: Context, id: Int) = manager(c).cancel(id)
    fun clear(c: Context) { pending(c).forEach { cancel(c,it) }; manager(c).cancelAll() }
    fun disabledChannels(c: Context): List<String> = if (Build.VERSION.SDK_INT >= 26)
        manager(c).notificationChannels.filter { it.importance == NotificationManager.IMPORTANCE_NONE }.map { it.name.toString() }
        else emptyList()
    fun deliver(c: Context, id: Int) {
        val raw = prefs(c).getString(id.toString(), null) ?: return
        val j = JSONObject(raw)
        cancel(c,id)
        if (foreground) return
        val date = j.optString("date", "")
        if (date.isNotEmpty() && date != "null") {
            val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
            if (date != today) return // Delayed inexact alarms never remind for a past date.
        }
        val sound = j.optBoolean("sound")
        val haptics = j.optBoolean("haptics")
        val theme = j.getString("theme").takeIf { it in listOf("mechanical","water","sundial") } ?: "mechanical"
        val channelId = "yike_${theme}_${if(sound) 1 else 0}_${if(haptics) 1 else 0}_v1"
        val soundUri = Uri.parse("android.resource://${c.packageName}/raw/${theme}_finish")
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(channelId, "一刻 · $theme · ${if(sound) "有声" else "静音"} · ${if(haptics) "振动" else "无振动"}", NotificationManager.IMPORTANCE_HIGH)
            channel.setSound(if(sound) soundUri else null,
                android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION).build())
            channel.enableVibration(haptics)
            manager(c).createNotificationChannel(channel)
        }
        val tap = Intent(c, MainActivity::class.java).setAction("YIKE_NOTIFICATION")
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("yike_payload", j.getString("payload"))
        val content = PendingIntent.getActivity(c,id,tap,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = NotificationCompat.Builder(c,channelId)
            .setSmallIcon(R.drawable.ic_notification).setContentTitle(j.getString("title"))
            .setContentText(j.getString("body")).setContentIntent(content).setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH).setCategory(NotificationCompat.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < 26) {
            builder.setSound(if(sound) soundUri else null)
            if(haptics) builder.setVibrate(longArrayOf(0,200))
        }
        manager(c).notify(id,builder.build())
    }
    fun rebuild(c: Context, timezoneChanged: Boolean) {
        for (id in pending(c)) {
            val raw = prefs(c).getString(id.toString(),null) ?: continue
            val j = JSONObject(raw)
            if (timezoneChanged && !j.optBoolean("timer")) {
                val parts = j.getString("date").split("-").map { it.toInt() }
                val minutes = j.getInt("minutes")
                val cal = Calendar.getInstance().apply {
                    clear(); set(parts[0],parts[1]-1,parts[2],minutes/60,minutes%60)
                }
                j.put("at",cal.timeInMillis)
            }
            if (j.getLong("at") > System.currentTimeMillis()) schedule(c,j) else cancel(c,id)
        }
    }
}
class YikeNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { YikeNotifications.deliver(context,intent.getIntExtra("id",-1)) }
        catch (_: Exception) { android.util.Log.e("YikeNotifications","Notification delivery failed") }
    }
}
class YikeNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { YikeNotifications.rebuild(context,intent.action == Intent.ACTION_TIMEZONE_CHANGED) }
        catch (_: Exception) { android.util.Log.e("YikeNotifications","Notification rebuild failed") }
    }
}
