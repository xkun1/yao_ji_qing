package com.kunge.yaojiqing

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class MedicationForegroundService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 8888
        private const val CHANNEL_ID = "yao_ji_qing_service_v9" // 强制更新通道
        private const val CHANNEL_NAME = "药管家极速守护"
        private const val ACTION_RESTART = "com.kunge.yaojiqing.RESTART_SERVICE"

        fun start(context: Context) {
            val intent = Intent(context, MedicationForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun updateNotification(context: Context, title: String, body: String) {
            val intent = Intent(context, MedicationForegroundService::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {}
        }
    }

    private var lastTitle = "药记清"
    private var lastBody = "用药提醒守护中..."

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title")
        val body = intent?.getStringExtra("body")
        
        if (title != null) lastTitle = title
        if (body != null) lastBody = body
        
        showForeground(lastTitle, lastBody)
        return START_STICKY // 杀掉后尽量自动重启
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // [核心加固] 当用户划掉 App 时，设置一个“最高等级”的闹钟复活
        resurrectService()
        super.onTaskRemoved(rootIntent)
    }

    private fun resurrectService() {
        val restartServiceIntent = Intent(applicationContext, MedicationVibrationReceiver::class.java).apply {
            action = ACTION_RESTART
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext, 
            1234, 
            restartServiceIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + 2000 // 2秒后复活

        // [核武器] setAlarmClock 是系统最高优先级闹钟，极难被杀
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val info = AlarmManager.AlarmClockInfo(triggerAt, pendingIntent)
            alarmManager.setAlarmClock(info, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun showForeground(title: String, body: String) {
        try {
            val notification = buildNotification(title, body)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(title: String, body: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        // 如果用户划掉通知，触发复活逻辑
        val deleteIntent = PendingIntent.getBroadcast(
            this, 5555, 
            Intent(this, MedicationVibrationReceiver::class.java).apply { action = ACTION_RESTART },
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(resources.getIdentifier("ic_launcher", "mipmap", packageName))
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX) // 最高优先级
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true) // 真正的常驻
            .setAutoCancel(false)
            .setDeleteIntent(deleteIntent) // 划掉就复活
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
