import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'email_database.dart';

class InAppAlarmService {
  static final InAppAlarmService _instance = InAppAlarmService._internal();
  factory InAppAlarmService() => _instance;
  InAppAlarmService._internal();

  static const platform = MethodChannel('com.example.mail_alarm/alarm');
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    _initialized = true;
    print('✓ In-app alarm service initialized with Android AlarmManager');
  }

  /// Schedule a ringing alarm for a specific date/time using Android AlarmManager
  Future<int> scheduleAlarm({
    required String emailId,
    required String subject,
    required String sender,
    required DateTime scheduledTime,
    String? emailLink,
  }) async {
    if (!_initialized) await initialize();

    // Generate unique notification ID based on email ID
    final int notificationId = emailId.hashCode.abs() % 2147483647;

    print('🔔 Scheduling ANDROID ALARMMANAGER ALARM:');
    print('  Email ID: $emailId');
    print('  Subject: $subject');
    print('  Scheduled: $scheduledTime');
    print('  Notification ID: $notificationId');

    try {
      // Call native Android code to schedule alarm using AlarmManager
      await platform.invokeMethod('scheduleAlarm', {
        'id': notificationId,
        'emailId': emailId,
        'subject': subject,
        'sender': sender,
        'scheduledTimeMillis': scheduledTime.millisecondsSinceEpoch,
      });

      // Save alarm info to preferences for management
      await _saveAlarmInfo(notificationId, emailId, subject, sender, scheduledTime);

      print('✓ ANDROID ALARMMANAGER ALARM scheduled successfully with ID: $notificationId');
      return notificationId;
    } catch (e) {
      print('❌ Error scheduling alarm: $e');
      rethrow;
    }
  }

  /// Cancel a specific alarm
  Future<void> cancelAlarm(String emailId) async {
    final int notificationId = emailId.hashCode.abs() % 2147483647;
    
    try {
      await platform.invokeMethod('cancelAlarm', {'id': notificationId});
      await _removeAlarmInfo(notificationId);
      print('✓ Cancelled alarm for email: $emailId (ID: $notificationId)');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  /// Cancel all alarms
  Future<void> cancelAllAlarms() async {
    try {
      // Get all alarm IDs from preferences
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString('scheduled_alarms') ?? '{}';
      final Map<String, dynamic> alarms = jsonDecode(alarmsJson);
      
      // Cancel each alarm
      for (String idStr in alarms.keys) {
        final id = int.parse(idStr);
        await platform.invokeMethod('cancelAlarm', {'id': id});
      }
      
      await prefs.remove('scheduled_alarms');
      print('✓ Cancelled all alarms');
    } catch (e) {
      print('❌ Error cancelling all alarms: $e');
    }
  }

  /// Get list of all pending alarms with their details
  Future<List<Map<String, dynamic>>> getPendingAlarmsWithDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString('scheduled_alarms') ?? '{}';
    final Map<String, dynamic> savedAlarms = jsonDecode(alarmsJson);
    
    List<Map<String, dynamic>> alarmsList = [];
    
    for (String idStr in savedAlarms.keys) {
      final alarmInfo = savedAlarms[idStr];
      if (alarmInfo != null) {
        final scheduledTime = DateTime.parse(alarmInfo['scheduledTime']);
        
        alarmsList.add({
          'id': int.parse(idStr),
          'emailId': alarmInfo['emailId'],
          'subject': alarmInfo['subject'],
          'sender': alarmInfo['sender'] ?? 'Unknown',
          'scheduledTime': scheduledTime,
          'createdAt': DateTime.parse(alarmInfo['createdAt']),
        });
      }
    }
    
    // Sort by scheduled time
    alarmsList.sort((a, b) => 
      (a['scheduledTime'] as DateTime).compareTo(b['scheduledTime'] as DateTime));
    
    print('📋 Found ${alarmsList.length} pending alarms in SharedPreferences');
    return alarmsList;
  }

  /// Get list of all pending alarms
  Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    // For now, return list based on SharedPreferences
    // In future, could query AlarmManager if needed
    final details = await getPendingAlarmsWithDetails();
    print('Pending alarms: ${details.length}');
    
    // Convert to PendingNotificationRequest format for compatibility
    return details.map((alarm) {
      return PendingNotificationRequest(
        alarm['id'] as int,
        alarm['subject'] as String,
        'From: ${alarm['sender']}',
        null,
      );
    }).toList();
  }

  /// Get alarm info for a specific email
  Future<Map<String, dynamic>?> getAlarmInfo(String emailId) async {
    final int notificationId = emailId.hashCode.abs() % 2147483647;
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString('scheduled_alarms') ?? '{}';
    final Map<String, dynamic> alarms = jsonDecode(alarmsJson);
    
    return alarms[notificationId.toString()];
  }

  /// Synchronizes the database with the alarms stored in SharedPreferences.
  /// This ensures the `hasAlarm` flag in the local DB is always accurate.
  Future<bool> syncWithDatabase() async {
    print('🔄 Starting database synchronization with alarm storage...');
    final db = EmailDatabase.instance;
    final alarms = await getPendingAlarmsWithDetails();
    final alarmEmailIds = alarms.map((a) => a['emailId'] as String).toSet();
    final allEmails = await db.getAllEmails();

    bool needsUpdate = false;
    for (final email in allEmails) {
      final bool hasAlarmInStorage = alarmEmailIds.contains(email.id);
      
      // Case 1: DB says it has an alarm, but storage doesn't. Fix DB.
      if (email.hasAlarm && !hasAlarmInStorage) {
        print('  - Sync Fix: Clearing alarm flag for "${email.subject}" (not in storage)');
        email.hasAlarm = false;
        email.alarmTimes = [];
        await db.updateEmail(email);
        needsUpdate = true;
      }
      // Case 2: Storage has an alarm, but DB says it doesn't. Fix DB.
      else if (!email.hasAlarm && hasAlarmInStorage) {
        print('  - Sync Fix: Setting alarm flag for "${email.subject}" (found in storage)');
        final alarmInfo = alarms.firstWhere((a) => a['emailId'] == email.id);
        email.hasAlarm = true;
        email.alarmTimes = [alarmInfo['scheduledTime'] as DateTime];
        await db.updateEmail(email);
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      print('✓ Database synchronization complete. Changes were made.');
    } else {
      print('✓ Database is already in sync with alarm storage.');
    }
    return needsUpdate;
  }

  /// Save alarm information for tracking
  Future<void> _saveAlarmInfo(
    int notificationId,
    String emailId,
    String subject,
    String sender,
    DateTime scheduledTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString('scheduled_alarms') ?? '{}';
    final Map<String, dynamic> alarms = jsonDecode(alarmsJson);
    
    alarms[notificationId.toString()] = {
      'emailId': emailId,
      'subject': subject,
      'sender': sender,
      'scheduledTime': scheduledTime.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString('scheduled_alarms', jsonEncode(alarms));
    await syncWithDatabase(); // Sync after saving
  }

  /// Remove alarm information
  Future<void> _removeAlarmInfo(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getString('scheduled_alarms') ?? '{}';
    final Map<String, dynamic> alarms = jsonDecode(alarmsJson);
    
    alarms.remove(notificationId.toString());
    await prefs.setString('scheduled_alarms', jsonEncode(alarms));
    await syncWithDatabase(); // Sync after removing
  }

  /// Check if an alarm exists for an email
  Future<bool> hasAlarm(String emailId) async {
    final int notificationId = emailId.hashCode.abs() % 2147483647;
    final alarmInfo = await getAlarmInfo(emailId);
    return alarmInfo != null;
  }
  
  /// Stop currently ringing alarm (called from dismiss button)
  static Future<void> stopAlarm() async {
    try {
      await platform.invokeMethod('stopAlarm');
      print('✓ Alarm stopped');
    } catch (e) {
      print('❌ Error stopping alarm: $e');
    }
  }
}
