package com.kunge.yaojiqing.yao_ji_qing

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.Intent

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleStopVibrationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleStopVibrationIntent(intent)
    }

    private fun handleStopVibrationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("stop_vibration", false) == true) {
            MedicationVibrationScheduler.stopActiveVibration(applicationContext)
            // 消费掉这个 intent，防止后续切屏重复触发
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
                        result.error("INVALID_ARGUMENTS", "id、title、body、hour、minute 不能为空", null)
                        return@setMethodCallHandler
                    }

                    MedicationVibrationScheduler.scheduleDaily(
                        context = applicationContext,
                        id = id,
                        title = title,
                        body = body,
                        hour = hour,
                        minute = minute
                    )
                    result.success(null)
                }
                "cancelDailyVibration" -> {
                    val id = call.argument<Int>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "id 不能为空", null)
                        return@setMethodCallHandler
                    }

                    MedicationVibrationScheduler.cancel(applicationContext, id)
                    result.success(null)
                }
                "stopActiveVibration" -> {
                    MedicationVibrationScheduler.stopActiveVibration(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
