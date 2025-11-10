package com.example.mail_alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmService : Service() {
    
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private val CHANNEL_ID = "bell_alarm_channel"
    private val NOTIFICATION_ID = 999
    private var stopAlarmRunnable: Runnable? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d("AlarmService", "Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmService", "Service started")
        
        try {
            val emailId = intent?.getStringExtra("emailId") ?: ""
            val subject = intent?.getStringExtra("subject") ?: "Alarm"
            val sender = intent?.getStringExtra("sender") ?: ""
            
            Log.d("AlarmService", "Creating notification for: $subject")
            
            // Start foreground notification FIRST before doing anything else
            val notification = createNotification(subject, sender)
            startForeground(NOTIFICATION_ID, notification)
            
            Log.d("AlarmService", "Foreground service started, now playing sound")
            
            // Play alarm sound
            playAlarmSound()
            
            // Start vibration
            startVibration()
            
            Log.d("AlarmService", "Alarm is now ringing")
            
            // Auto-stop alarm after 90 seconds
            stopAlarmRunnable = Runnable {
                Log.d("AlarmService", "90 seconds elapsed, stopping alarm")
                stopSelf()
            }
            handler.postDelayed(stopAlarmRunnable!!, 90000) // 90 seconds
            
        } catch (e: Exception) {
            Log.e("AlarmService", "Error in onStartCommand", e)
            // Even if there's an error, try to show a basic notification
            try {
                val basicNotification = createBasicNotification()
                startForeground(NOTIFICATION_ID, basicNotification)
            } catch (e2: Exception) {
                Log.e("AlarmService", "Failed to create even basic notification", e2)
            }
        }
        
        return START_STICKY
    }
    
    private fun createBasicNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Bell Alarm")
            .setContentText("Alarm is ringing")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .build()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Bell Alarms"
            val descriptionText = "Ringing alarms for emails"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(subject: String, sender: String): Notification {
        try {
            // Intent to open the app when notification is tapped
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Intent to dismiss the alarm
            val dismissIntent = Intent(this, AlarmDismissReceiver::class.java)
            val dismissPendingIntent = PendingIntent.getBroadcast(
                this, 0, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("🔔 ALARM: Email Reminder")
                .setContentText(subject)
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("📧 $subject\n\nFrom: $sender"))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pendingIntent, true)
                .setOngoing(true)
                .setAutoCancel(false)
                .setColor(0xFFFFC107.toInt())
                .addAction(android.R.drawable.ic_delete, "Dismiss", dismissPendingIntent)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build()
        } catch (e: Exception) {
            Log.e("AlarmService", "Error creating notification", e)
            // Return basic notification as fallback
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Bell Alarm")
                .setContentText(subject)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .build()
        }
    }
    
    private fun playAlarmSound() {
        try {
            // Request audio focus for alarm
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(false)
                    .setWillPauseWhenDucked(false)
                    .build()
                
                val result = audioManager?.requestAudioFocus(audioFocusRequest!!)
                if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    Log.w("AlarmService", "Audio focus not granted")
                }
            } else {
                @Suppress("DEPRECATION")
                val result = audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN
                )
                if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    Log.w("AlarmService", "Audio focus not granted")
                }
            }
            
            // Get default alarm sound
            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                        .build()
                )
                
                // Set to alarm stream explicitly
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                }
                
                isLooping = true // Loop continuously until stopped
                setVolume(1.0f, 1.0f) // Maximum volume
                
                setOnPreparedListener {
                    Log.d("AlarmService", "MediaPlayer prepared, starting playback")
                    try {
                        start()
                        Log.d("AlarmService", "MediaPlayer started successfully, isPlaying=${isPlaying}")
                    } catch (e: Exception) {
                        Log.e("AlarmService", "Error starting MediaPlayer", e)
                    }
                }
                
                setOnErrorListener { mp, what, extra ->
                    Log.e("AlarmService", "MediaPlayer error: what=$what, extra=$extra")
                    // Try to restart
                    try {
                        mp.reset()
                        mp.setDataSource(applicationContext, alarmUri)
                        mp.prepareAsync()
                    } catch (e: Exception) {
                        Log.e("AlarmService", "Failed to restart MediaPlayer", e)
                    }
                    true // Return true to indicate we handled the error
                }
                
                setOnCompletionListener {
                    Log.d("AlarmService", "MediaPlayer completed (shouldn't happen with looping)")
                }
                
                prepareAsync() // Prepare asynchronously to avoid blocking
            }
            
            Log.d("AlarmService", "Alarm sound preparing...")
        } catch (e: Exception) {
            Log.e("AlarmService", "Error playing alarm sound", e)
        }
    }
    
    private fun startVibration() {
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Vibration pattern: wait 0ms, vibrate 1000ms, wait 500ms, repeat
            val pattern = longArrayOf(0, 1000, 500)
            val vibrationEffect = VibrationEffect.createWaveform(pattern, 0) // 0 = repeat from beginning
            vibrator?.vibrate(vibrationEffect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, 1000, 500)
            vibrator?.vibrate(pattern, 0) // 0 = repeat from beginning
        }
        
        Log.d("AlarmService", "Vibration started")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d("AlarmService", "Service destroyed - stopping alarm")
        
        // Cancel auto-stop if scheduled
        stopAlarmRunnable?.let { handler.removeCallbacks(it) }
        
        // Stop media player
        mediaPlayer?.apply {
            try {
                if (isPlaying) {
                    stop()
                }
                release()
            } catch (e: Exception) {
                Log.e("AlarmService", "Error stopping MediaPlayer", e)
            }
        }
        mediaPlayer = null
        
        // Release audio focus
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(null)
        }
        audioManager = null
        
        // Stop vibration
        vibrator?.cancel()
        vibrator = null
    }
}
