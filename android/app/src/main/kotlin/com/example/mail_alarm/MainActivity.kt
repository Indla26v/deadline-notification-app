package com.example.mail_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.mail_alarm/alarm"
    private var alarmManager: AlarmManager? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        val emailId = call.argument<String>("emailId") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val sender = call.argument<String>("sender") ?: ""
                        val scheduledTimeMillis = call.argument<Long>("scheduledTimeMillis") ?: 0L
                        
                        scheduleAlarm(id, emailId, subject, sender, scheduledTimeMillis)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error scheduling alarm", e)
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        cancelAlarm(id)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error cancelling alarm", e)
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        val serviceIntent = Intent(this, AlarmService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error stopping alarm", e)
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun scheduleAlarm(id: Int, emailId: String, subject: String, sender: String, scheduledTimeMillis: Long) {
        // Convert millis to readable date for logging
        val scheduledDate = java.util.Date(scheduledTimeMillis)
        val dateFormat = java.text.SimpleDateFormat("MMM dd, yyyy HH:mm:ss", java.util.Locale.getDefault())
        val scheduledDateStr = dateFormat.format(scheduledDate)
        
        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d("MainActivity", "SCHEDULING ALARM:")
        Log.d("MainActivity", "  ID: $id")
        Log.d("MainActivity", "  Subject: $subject")
        Log.d("MainActivity", "  Millis: $scheduledTimeMillis")
        Log.d("MainActivity", "  Scheduled for: $scheduledDateStr")
        Log.d("MainActivity", "  Current time: ${dateFormat.format(java.util.Date())}")
        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("emailId", emailId)
            putExtra("subject", subject)
            putExtra("sender", sender)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use setAlarmClock for maximum reliability - shows alarm icon in status bar
        // and is exempt from all battery optimizations
        val alarmClockInfo = AlarmManager.AlarmClockInfo(
            scheduledTimeMillis,
            pendingIntent // Show pending intent when alarm icon is tapped
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            alarmManager?.setAlarmClock(alarmClockInfo, pendingIntent)
            Log.d("MainActivity", "✓ Alarm scheduled using setAlarmClock (most reliable)")
        } else {
            // Fallback for older devices
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager?.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTimeMillis,
                    pendingIntent
                )
            } else {
                alarmManager?.setExact(
                    AlarmManager.RTC_WAKEUP,
                    scheduledTimeMillis,
                    pendingIntent
                )
            }
            Log.d("MainActivity", "✓ Alarm scheduled using setExact/setExactAndAllowWhileIdle")
        }
        
        Log.d("MainActivity", "✓ Alarm scheduled successfully")
    }
    
    private fun cancelAlarm(id: Int) {
        Log.d("MainActivity", "Cancelling alarm: id=$id")
        
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager?.cancel(pendingIntent)
        pendingIntent.cancel()
        
        Log.d("MainActivity", "✓ Alarm cancelled")
    }
}

