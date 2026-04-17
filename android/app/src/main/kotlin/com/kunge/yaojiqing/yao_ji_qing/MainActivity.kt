package com.kunge.yaojiqing

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.Intent
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.app.AlarmManager
import android.app.PendingIntent
import androidx.core.app.NotificationManagerCompat

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleStopVibrationIntent(intent)
        
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            MedicationForegroundService.start(applicationContext)
        }, 1000)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleStopVibrationIntent(intent)
    }

    private fun handleStopVibrationIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("stop_vibration", false)) {
            MedicationVibrationScheduler.stopActiveVibration(applicationContext)
            intent.removeExtra("stop_vibration")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "yao_ji_qing/medication_vibration"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDailyVibration" -> {
                    val id = call.argument<Int>("id")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val hour = call.argument<Int>("hour")
                    val minute = call.argument<Int>("minute")

                    if (id == null || title == null || body == null || hour == null || minute == null) {
                        result.error("INVALID_ARGUMENTS", "参数不能为空", null)
                        return@setMethodCallHandler
                    }

                    MedicationVibrationScheduler.scheduleDaily(applicationContext, id, title, body, hour, minute)
                    result.success(null)
                }
                "cancelDailyVibration" -> {
                    val id = call.argument<Int>("id")
                    if (id != null) MedicationVibrationScheduler.cancel(applicationContext, id)
                    result.success(null)
                }
                "stopActiveVibration" -> {
                    MedicationVibrationScheduler.stopActiveVibration(applicationContext)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    val intent = Intent(applicationContext, MedicationForegroundService::class.java)
                    applicationContext.stopService(intent)
                    result.success(null)
                }
                "startForegroundService" -> {
                    MedicationForegroundService.start(applicationContext)
                    result.success(null)
                }
                "updateForegroundService" -> {
                    val title = call.argument<String>("title") ?: "药记清"
                    val body = call.argument<String>("body") ?: "用药提醒守护中..."
                    MedicationForegroundService.updateNotification(applicationContext, title, body)
                    result.success(null)
                }
                "openAppSettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.fromParts("package", packageName, null)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "openBatterySettings" -> {
                    val intent = Intent().apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                        } else {
                            action = android.provider.Settings.ACTION_SETTINGS
                        }
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    try {
                        startActivity(intent)
                    } catch (e: Exception) {
                        startActivity(Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        })
                    }
                    result.success(null)
                }
                "openAutoStartSettings" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val intents = mutableListOf<Intent>()

                    when {
                        manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                            // 路径 1: 新版华为/荣耀启动管理
                            intents.add(Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")))
                            // 路径 2: 荣耀独立后的新包名
                            intents.add(Intent().setComponent(android.content.ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")))
                            // 路径 3: 老版华为受保护应用
                            intents.add(Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")))
                        }
                        manufacturer.contains("xiaomi") -> {
                            intents.add(Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")))
                        }
                    }

                    // 兜底路径：应用详情页
                    val backupIntent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.fromParts("package", packageName, null)
                    }
                    intents.add(backupIntent)

                    var success = false
                    for (intent in intents) {
                        try {
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            success = true
                            break
                        } catch (e: Exception) {
                            continue
                        }
                    }
                    result.success(success)
                }
                "checkActualPermissions" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    
                    val isBatteryIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else true

                    val canScheduleAlarms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else true

                    val notificationsEnabled = NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()

                    result.success(mapOf(
                        "batteryIgnored" to isBatteryIgnored,
                        "alarmsEnabled" to canScheduleAlarms,
                        "notificationsEnabled" to notificationsEnabled
                    ))
                }
                "restartApp" -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    val restartIntent = PendingIntent.getActivity(
                        applicationContext, 
                        9999, 
                        intent, 
                        PendingIntent.FLAG_CANCEL_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 100, restartIntent)
                    android.os.Process.killProcess(android.os.Process.myPid())
                    System.exit(0)
                }
                else -> result.notImplemented()
            }
        }
    }
}
