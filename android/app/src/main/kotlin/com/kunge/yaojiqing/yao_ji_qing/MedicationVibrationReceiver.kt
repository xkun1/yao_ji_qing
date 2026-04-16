package com.kunge.yaojiqing.yao_ji_qing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager

class MedicationVibrationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "YaoJiQing:AlarmWakeLock")
        
        try {
            // 申请 5 秒钟的唤醒锁，确保马达启动成功
            wakeLock.acquire(5000L)
            
            if (MedicationVibrationScheduler.isStopAction(intent)) {
                MedicationVibrationScheduler.handleStopTriggered(context, intent)
            } else {
                MedicationVibrationScheduler.handleReminderTriggered(context, intent)
            }
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}
