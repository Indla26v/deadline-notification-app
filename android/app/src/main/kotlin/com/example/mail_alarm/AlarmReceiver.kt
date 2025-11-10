package com.example.mail_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Alarm received!")
        
        // Acquire wake lock to ensure device wakes up
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "Bell::AlarmWakeLock"
        )
        wakeLock.acquire(60000) // Hold for 1 minute max
        
        try {
            // Get alarm details from intent
            val emailId = intent.getStringExtra("emailId") ?: ""
            val subject = intent.getStringExtra("subject") ?: "Alarm"
            val sender = intent.getStringExtra("sender") ?: ""
            
            Log.d("AlarmReceiver", "Email: $emailId, Subject: $subject")
            
            // Start the AlarmService to handle ringing
            val serviceIntent = Intent(context, AlarmService::class.java).apply {
                putExtra("emailId", emailId)
                putExtra("subject", subject)
                putExtra("sender", sender)
            }
            
            // Start foreground service (required for Android 8.0+)
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                    Log.d("AlarmReceiver", "Started foreground service")
                } else {
                    context.startService(serviceIntent)
                    Log.d("AlarmReceiver", "Started service")
                }
            } catch (e: Exception) {
                Log.e("AlarmReceiver", "Error starting service", e)
                // Try to show a basic notification as fallback
                showFallbackNotification(context, subject)
            }
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error in onReceive", e)
            showFallbackNotification(context, "Alarm")
        } finally {
            // Release wake lock
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
    
    private fun showFallbackNotification(context: Context, subject: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    "bell_fallback",
                    "Bell Fallback",
                    android.app.NotificationManager.IMPORTANCE_HIGH
                )
                notificationManager.createNotificationChannel(channel)
            }
            
            val notification = android.app.Notification.Builder(context, "bell_fallback")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Bell Alarm")
                .setContentText(subject)
                .build()
            
            notificationManager.notify(999, notification)
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Even fallback notification failed", e)
        }
    }
}
