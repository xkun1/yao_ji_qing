package com.kunge.yaojiqing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MedicationVibrationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                MedicationVibrationScheduler.rescheduleAll(context)
            }
        }
    }
}
