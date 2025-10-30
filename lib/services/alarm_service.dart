import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    // Initialize time zone database
    try {
      tzdata.initializeTimeZones();
      // Set to Asia/Kolkata timezone (Indian Standard Time)
      // Change this if you're in a different timezone
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      print('Error initializing timezone: $e');
    }

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        try {
          final payload = response.payload;
          print('Notification response received. payload: $payload');

          // Payload format: "emailId|link" or just "link"
          if (payload != null && payload.isNotEmpty) {
            if (payload.contains('|')) {
              // New format with email ID
              final parts = payload.split('|');
              final emailId = parts[0];
              // Navigate to email detail (handled in main.dart)
              notificationClickCallback?.call(emailId);
            } else {
              // Old format - just open link
              await launchUrl(Uri.parse(payload), mode: LaunchMode.externalApplication);
            }
          }
        } catch (e) {
          print('Error handling notification response: $e');
        }
      },
    );
  }

  // Callback for notification clicks
  static Function(String emailId)? notificationClickCallback;

  Future<void> requestAndroidPermissions() async {
    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      print('Requesting notification permissions...');
      final notifGranted = await androidImpl.requestNotificationsPermission();
      print('Notification permission granted: $notifGranted');
      
      print('Requesting exact alarm permissions...');
      final alarmGranted = await androidImpl.requestExactAlarmsPermission();
      print('Exact alarm permission granted: $alarmGranted');
      
      // Check if we can schedule exact alarms
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      print('Can schedule exact notifications: $canSchedule');
    }
  }

  Future<void> showImmediateTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications to verify notifications work',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFFFC107), // Bell amber/gold color
      icon: '@mipmap/ic_launcher',
    );
    
    await _notificationsPlugin.show(
      999998,
      '🔔 Bell - Test Notification',
      'If you see this, notifications are working!',
      const NotificationDetails(android: androidDetails),
    );
    
    print('Immediate test notification sent');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    print('Total pending notifications: ${pending.length}');
    for (final p in pending) {
      print('  - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}');
    }
    return pending;
  }

  Future<void> scheduleAlarm({
    required String label,
    required DateTime scheduledDate,
    required String link,
    String? emailId,
  }) async {
    // Check if the scheduled time is in the past
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      print('WARNING: Scheduled time is in the past! Alarm will not trigger.');
      throw Exception('Scheduled time (${DateFormat('MMM d, h:mm a').format(scheduledDate)}) has already passed. Please choose a future time.');
    }

    print('=== SCHEDULING SYSTEM ALARM ===');
    print('Label: $label');
    print('Scheduled time: $scheduledDate');
    print('Email link: $link');
    print('Email ID: $emailId');
    
    try {
      // Calculate days from now (0 = today, 1 = tomorrow, etc.)
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final daysFromNow = targetDate.difference(today).inDays;
      
      // Create a system alarm using Android Clock app with date support
      final arguments = <String, dynamic>{
        'android.intent.extra.alarm.HOUR': scheduledDate.hour,
        'android.intent.extra.alarm.MINUTES': scheduledDate.minute,
        'android.intent.extra.alarm.MESSAGE': '📧 $label',
        'android.intent.extra.alarm.SKIP_UI': true, // Don't show Clock UI, just set the alarm
      };
      
      // Add date information if alarm is not for today
      if (daysFromNow > 0) {
        // Use DAYS parameter to set alarm for future date
        arguments['android.intent.extra.alarm.DAYS'] = [_getDayOfWeek(scheduledDate)];
        
        // Also try setting the exact date (some devices support this)
        arguments['android.intent.extra.alarm.YEAR'] = scheduledDate.year;
        arguments['android.intent.extra.alarm.MONTH'] = scheduledDate.month - 1; // Android months are 0-based
        arguments['android.intent.extra.alarm.DAY'] = scheduledDate.day;
      }
      
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: arguments,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      
      await intent.launch();
      print('✓ System alarm created successfully!');
      
    } catch (e) {
      print('✗ Error creating system alarm: $e');
      rethrow;
    }

    // Show a confirmation notification with date and email ID in payload
    final dateStr = DateFormat('MMM d').format(scheduledDate);
    final timeStr = DateFormat('h:mm a').format(scheduledDate);
    final payload = emailId != null ? '$emailId|$link' : link;
    
    await _notificationsPlugin.show(
      999999,
      '🔔 Bell - Alarm Set',
      'Alarm for "${label}"\nScheduled: $dateStr at $timeStr\nCheck your Clock app to manage it.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'confirmation_channel',
          'Confirmations',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          timeoutAfter: 5000,
          color: Color(0xFFFFC107), // Bell amber/gold color
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  // Get day of week for Android alarm (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
  int _getDayOfWeek(DateTime date) {
    // DateTime.weekday: 1 = Monday, 7 = Sunday
    // Android: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    return date.weekday == 7 ? 1 : date.weekday + 1;
  }

  DateTime? parseTimeFromText(String text) {
    print('=== PARSING TIME FROM TEXT ===');
    print('Input text: $text');
    
    // First try to find date + time patterns (more specific)
    final dateTimePatterns = <RegExp>[
      // Matches: "8th November at 8:30 am", "30th October 2026 at 10:30 AM"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:(\d{4})\s+)?at\s+(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "November 8 at 8:30 am", "October 30, 2026 at 10:30 AM"
      RegExp(r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(?:(\d{4})\s+)?at\s+(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "on 8th Nov at 8:30 am"
      RegExp(r"on\s+(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(?:(\d{4})\s+)?at\s+(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
    ];

    for (final pattern in dateTimePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        print('Date-time pattern matched: ${match.group(0)}');
        try {
          String? monthStr;
          int? day;
          int? year;
          int? hour;
          int? minute;
          String? ampm;

          // Determine if it's day-first or month-first pattern
          final firstGroup = match.group(1)!;
          if (RegExp(r'^\d+$').hasMatch(firstGroup)) {
            // Pattern: "8th November at 8:30 am"
            day = int.parse(firstGroup.replaceAll(RegExp(r'[^\d]'), ''));
            monthStr = match.group(2);
            year = match.group(3) != null ? int.tryParse(match.group(3)!) : null;
            hour = int.tryParse(match.group(4)!);
            minute = match.group(5) != null ? int.tryParse(match.group(5)!) : 0;
            ampm = match.group(6);
          } else {
            // Pattern: "November 8 at 8:30 am"
            monthStr = match.group(1);
            day = int.parse(match.group(2)!.replaceAll(RegExp(r'[^\d]'), ''));
            year = match.group(3) != null ? int.tryParse(match.group(3)!) : null;
            hour = int.tryParse(match.group(4)!);
            minute = match.group(5) != null ? int.tryParse(match.group(5)!) : 0;
            ampm = match.group(6);
          }

          if (day != null && hour != null && monthStr != null) {
            // Parse month name
            final months = ['january', 'february', 'march', 'april', 'may', 'june', 
                          'july', 'august', 'september', 'october', 'november', 'december'];
            final monthLower = monthStr.toLowerCase();
            final monthIndex = months.indexWhere((m) => monthLower.startsWith(m.substring(0, 3)));
            
            if (monthIndex >= 0) {
              final month = monthIndex + 1; // Convert to 1-based month
              
              // If no year provided, determine based on month
              if (year == null) {
                final now = DateTime.now();
                year = now.year;
                // If month has passed this year, use next year
                if (month < now.month || (month == now.month && day < now.day)) {
                  year++;
                }
              }
              
              // Convert to 24-hour if AM/PM is present
              if (ampm != null) {
                final ampmLower = ampm.toLowerCase();
                if (ampmLower == 'pm' && hour < 12) {
                  hour += 12;
                } else if (ampmLower == 'am' && hour == 12) {
                  hour = 0;
                }
              }

              final result = DateTime(year, month, day, hour, minute ?? 0);
              print('Parsed date-time: $result');
              return result;
            }
          }
        } catch (e) {
          print('Error parsing date-time: $e');
        }
      }
    }

    // Fallback to time-only patterns
    final timePatterns = <RegExp>[
      // Matches: "13:52", "09:30", "18:25" (24-hour format) - Check this FIRST
      RegExp(r"\b([01]?\d|2[0-3]):([0-5]\d)\b"),
      // Matches: "1:52 PM", "10:30 AM", "3 PM" (12-hour format with AM/PM)
      RegExp(r"(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)", caseSensitive: false),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          int hour = int.parse(match.group(1)!);
          int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
          final ampm = match.group(3);

          // Convert to 24-hour if AM/PM is present
          if (ampm != null) {
            if (ampm.toLowerCase() == 'pm' && hour < 12) {
              hour += 12;
            } else if (ampm.toLowerCase() == 'am' && hour == 12) {
              hour = 0;
            }
          }

          // Use detected date or next occurrence
          return _toNextOccurrence(hour, minute);
        } catch (_) {}
      }
    }

    return null;
  }

  DateTime _toNextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If time has passed today, schedule for same time today if it's still in future
    // Otherwise schedule for tomorrow
    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    return scheduled;
  }
}


