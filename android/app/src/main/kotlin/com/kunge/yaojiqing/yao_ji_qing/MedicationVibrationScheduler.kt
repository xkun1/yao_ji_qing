package com.kunge.yaojiqing.yao_ji_qing

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.util.Calendar

object MedicationVibrationScheduler {
    private const val ACTION_VIBRATE = "com.kunge.yaojiqing.yao_ji_qing.MEDICATION_VIBRATE"
    private const val ACTION_STOP_VIBRATION = "com.kunge.yaojiqing.yao_ji_qing.STOP_MEDICATION_VIBRATION"
    private const val PREFS_NAME = "medication_vibration_reminders"
    private const val ACTIVE_PREFS_NAME = "active_medication_vibration"
    private const val ACTIVE_ID_KEY = "active_id"
    private const val PREF_KEY_PREFIX = "reminder_"
    private const val EXTRA_ID = "id"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_BODY = "body"
    private const val EXTRA_HOUR = "hour"
    private const val EXTRA_MINUTE = "minute"
    private const val STOP_REQUEST_CODE_OFFSET = 1_000_000
    private const val MAX_VIBRATION_DURATION_MS = 10 * 60 * 1000L
    private val vibrationPattern = longArrayOf(0, 1200, 400, 1200, 400, 1800)

    fun scheduleDaily(context: Context, id: Int, title: String, body: String, hour: Int, minute: Int) {
        saveReminder(context, id, title, body, hour, minute)
        scheduleDailyAlarm(context, id, hour, minute)
    }

    fun cancel(context: Context, id: Int) {
        removeReminder(context, id)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(
            buildPendingIntent(
                context = context,
                id = id,
                hour = 0,
                minute = 0,
                flags = PendingIntent.FLAG_NO_CREATE or immutableFlag()
            ) ?: return
        )
        stopActiveVibration(context, id)
    }

    fun rescheduleFromIntent(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        val hour = intent.getIntExtra(EXTRA_HOUR, -1)
        val minute = intent.getIntExtra(EXTRA_MINUTE, -1)
        if (id < 0 || hour !in 0..23 || minute !in 0..59) return

        scheduleDailyAlarm(context, id, hour, minute)
    }

    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.all.forEach { (key, value) ->
            if (!key.startsWith(PREF_KEY_PREFIX) || value !is String) return@forEach

            val id = key.removePrefix(PREF_KEY_PREFIX).toIntOrNull() ?: return@forEach
            val parts = value.split("|||")
            if (parts.size != 4) return@forEach

            val hour = parts[2].toIntOrNull() ?: return@forEach
            val minute = parts[3].toIntOrNull() ?: return@forEach
            if (hour !in 0..23 || minute !in 0..59) return@forEach

            scheduleDailyAlarm(context, id, hour, minute)
        }
    }

    fun handleReminderTriggered(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        val hour = intent.getIntExtra(EXTRA_HOUR, -1)
        val minute = intent.getIntExtra(EXTRA_MINUTE, -1)

        if (id >= 0) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val data = prefs.getString("$PREF_KEY_PREFIX$id", null)
            val parts = data?.split("|||")
            val title = parts?.getOrNull(0) ?: "用药提醒"
            val body = parts?.getOrNull(1) ?: "坤哥，该吃药了！"
            
            startActiveVibration(context, id, title, body)
        }

        if (id >= 0 && hour in 0..23 && minute in 0..59) {
            scheduleDailyAlarm(context, id, hour, minute)
        }
    }

    fun handleStopTriggered(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        stopActiveVibration(context, id)
    }

    fun isStopAction(intent: Intent): Boolean {
        return intent.action == ACTION_STOP_VIBRATION
    }

    fun stopActiveVibration(context: Context, expectedId: Int? = null) {
        val prefs = context.getSharedPreferences(ACTIVE_PREFS_NAME, Context.MODE_PRIVATE)
        val activeId = prefs.getInt(ACTIVE_ID_KEY, -1)
        if (expectedId != null && expectedId >= 0 && activeId >= 0 && activeId != expectedId) {
            return
        }

        getVibrator(context).cancel()
        prefs.edit().remove(ACTIVE_ID_KEY).apply()

        if (activeId >= 0) {
            cancelStopAlarm(context, activeId)
            // 同时取消通知栏显示
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(activeId)
        }
    }

    private fun startActiveVibration(context: Context, id: Int, title: String, body: String) {
        stopActiveVibration(context)

        val vibrator = getVibrator(context)
        if (!vibrator.hasVibrator()) return

        context.getSharedPreferences(ACTIVE_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putInt(ACTIVE_ID_KEY, id)
            .apply()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(vibrationPattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(vibrationPattern, 0)
        }

        // 显示通知并绑定删除意图（DeleteIntent）
        showNotificationWithDeleteIntent(context, id, title, body)
        scheduleStopAlarm(context, id)
    }

    private fun showNotificationWithDeleteIntent(context: Context, id: Int, title: String, body: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val channelId = "med_reminders_alarm_v4"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                "用药提醒通道",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "系统会按时提醒用户吃药，并震动提示。"
                enableVibration(true)
                vibrationPattern = this@MedicationVibrationScheduler.vibrationPattern
            }
            notificationManager.createNotificationChannel(channel)
        }

        val deleteIntent = buildStopPendingIntent(context, id, PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag())
        val contentIntent = Intent(context, MainActivity::class.java).let {
            it.putExtra("stop_vibration", true) // 埋下标记
            PendingIntent.getActivity(context, id, it, PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag())
        }

        val builder = androidx.core.app.NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName))
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setDeleteIntent(deleteIntent)
            .setContentIntent(contentIntent)

        notificationManager.notify(id, builder.build())
    }

    private fun scheduleDailyAlarm(context: Context, id: Int, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = nextTriggerAtMillis(hour, minute)
        val pendingIntent = buildPendingIntent(
            context = context,
            id = id,
            hour = hour,
            minute = minute,
            flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        ) ?: return

        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
                else -> {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            }
        } catch (_: SecurityException) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun scheduleStopAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildStopPendingIntent(
            context = context,
            id = id,
            flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        ) ?: return
        val triggerAtMillis = System.currentTimeMillis() + MAX_VIBRATION_DURATION_MS

        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
                else -> {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            }
        } catch (_: SecurityException) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun cancelStopAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(
            buildStopPendingIntent(
                context = context,
                id = id,
                flags = PendingIntent.FLAG_NO_CREATE or immutableFlag()
            ) ?: return
        )
    }

    private fun nextTriggerAtMillis(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val trigger = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        if (!trigger.after(now)) {
            trigger.add(Calendar.DAY_OF_MONTH, 1)
        }

        return trigger.timeInMillis
    }

    private fun buildPendingIntent(
        context: Context,
        id: Int,
        hour: Int,
        minute: Int,
        flags: Int
    ): PendingIntent? {
        val intent = Intent(context, MedicationVibrationReceiver::class.java).apply {
            action = ACTION_VIBRATE
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }

        return PendingIntent.getBroadcast(context, id, intent, flags)
    }

    private fun buildStopPendingIntent(
        context: Context,
        id: Int,
        flags: Int
    ): PendingIntent? {
        val intent = Intent(context, MedicationVibrationReceiver::class.java).apply {
            action = ACTION_STOP_VIBRATION
            putExtra(EXTRA_ID, id)
        }

        return PendingIntent.getBroadcast(context, id + STOP_REQUEST_CODE_OFFSET, intent, flags)
    }

    private fun saveReminder(context: Context, id: Int, title: String, body: String, hour: Int, minute: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString("$PREF_KEY_PREFIX$id", "$title|||$body|||$hour|||$minute")
            .apply()
    }

    private fun removeReminder(context: Context, id: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove("$PREF_KEY_PREFIX$id")
            .apply()
    }

    private fun getVibrator(context: Context): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}
