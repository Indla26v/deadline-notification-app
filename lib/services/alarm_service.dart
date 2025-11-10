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
      'Bell - Test',
      channelDescription: 'Test notifications to verify notifications work',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFFFFC107), // Bell amber/gold color
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      when: null,
      showWhen: true,
      category: AndroidNotificationCategory.message,
    );
    
    await _notificationsPlugin.show(
      999998,
      'Bell • Now 🔔',
      'Test Notification',
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
    
    final confirmationText = 'Alarm for "${label}"\nScheduled: $dateStr at $timeStr\nCheck your Clock app to manage it.';
    
    final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
      confirmationText,
      htmlFormatBigText: false,
      contentTitle: 'Alarm Set',
      htmlFormatContentTitle: false,
      summaryText: 'Tap to view email',
      htmlFormatSummaryText: false,
    );
    
    await _notificationsPlugin.show(
      999999,
      'Bell • Now 🔔',
      'Alarm Set',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'confirmation_channel',
          'Bell - Confirmations',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          timeoutAfter: 5000,
          color: const Color(0xFFFFC107), // Bell amber/gold color
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: bigTextStyle,
          when: DateTime.now().millisecondsSinceEpoch,
          showWhen: true,
          category: AndroidNotificationCategory.reminder,
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

  Map<String, dynamic>? parseTimeFromText(String text) {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║          PARSING EMAIL BODY FOR DATE/TIME                 ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📧 EMAIL BODY TEXT (${text.length} characters):');
    print('┌────────────────────────────────────────────────────────────┐');
    print(text.replaceAll('\n', ' ').substring(0, text.length > 500 ? 500 : text.length)); // Print first 500 chars
    print('└────────────────────────────────────────────────────────────┘\n');

    final now = DateTime.now();
    final List<Map<String, dynamic>> candidates = [];
    final List<String> candidatesLog = [];

    // =========================================================================
    // PASS 1A: Search for START times first (highest priority)
    // Look for "from", "starting", "begins", etc.
    // =========================================================================
    print('--- PASS 1A: Searching for START time patterns (from/starting/begins) ---');
    final startTimePatterns = <RegExp>[
      // "from 31st October 2025" or "from 31st Oct 2025 9:00 am"
      RegExp(r"(?:from|starting\s+from|begins\s+on)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:(\d{4})\s+)?(?:(\d{1,2})[:\.](\d{2})\s*(am|pm)?)?", caseSensitive: false),
      RegExp(r"(?:from|starting\s+from|begins\s+on)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(?:(\d{4})\s+)?(?:(\d{1,2})[:\.](\d{2})\s*(am|pm)?)?", caseSensitive: false),
      // "Scheduled from 31-10-2025" or "from 31/10/2025"
      RegExp(r"(?:from|starting\s+from|scheduled\s+from)\s+(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})(?:\s+(?:at\s+)?(\d{1,2})[:\.](\d{2})\s*(am|pm)?)?", caseSensitive: false),
    ];
    
    _parseMatches(text, startTimePatterns, candidates, candidatesLog, 'start-time');
    
    // If we found start times, use the EARLIEST one (first to start)
    var futureCandidates = candidates.where((c) => (c['date'] as DateTime).isAfter(now)).toList();
    if (futureCandidates.isNotEmpty) {
      print('--- PASS 1A SUCCESS: Found START time(s). Selecting earliest. ---');
      futureCandidates.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      final selected = futureCandidates.first;
      final selectedDate = selected['date'] as DateTime;
      
      candidatesLog.add("\n[PASS 1A - START TIME] Selected: ${DateFormat('MMM d, yyyy h:mm a').format(selectedDate)} (event start time)");
      print('  ✓ Selected start time: $selectedDate');
      
      return {'finalDate': selectedDate, 'candidatesLog': candidatesLog};
    }
    
    // Clear candidates for next pass
    candidates.clear();

    // =========================================================================
    // PASS 1B: Search for full DATE + TIME patterns (general event times)
    // =========================================================================
    print('--- PASS 1B: Searching for general Date + Time patterns ---');
    final dateTimePatterns = <RegExp>[
      // SPECIAL: Handle Noon/Midnight with ordinal dates: "3rd November 2025 by 12 Noon"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:(\d{4})\s+)?(?:at|by)\s+(?:12\s*)?(noon|midnight)", caseSensitive: false),
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(?:(\d{4})\s+)?(?:at|by)\s+(?:12\s*)?(noon|midnight)", caseSensitive: false),
      // PRIORITY: Numeric dates with @ symbol: "*31-10-2025 @ 8.00PM*"
      RegExp(r"(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})\s*@\s*(\d{1,2})[:\.](\d{2})\s*(am|pm)?", caseSensitive: false),
      // PRIORITY: Numeric date with at/by later in the text: "04.11.2025 ... by 8:30 am" or "on 04/11/2025 at 8:30 am" or "02.11.2025 at chennai campus,by 8:30 am"
      RegExp(r"(?:on\s+)?(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4}).*?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?", caseSensitive: false, dotAll: true),
      // PRIORITY: Numeric date immediately followed by time: "04-11-2025 8:30 am"
      RegExp(r"(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "DATE: 14TH NOV" followed by "TIME: 6:00 PM" (multiline with DATE and TIME keywords)
      RegExp(r"DATE:\s*(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*.*?TIME:\s*(\d{1,2})[:\.](\d{2})\s*(am|pm)?", caseSensitive: false, multiLine: true, dotAll: true),
      // Matches: "8th November at 8:30 am", "30th October 2026 at 10:30 AM", "3rd November 2025 by 8.30 am"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(?:(\d{4})\s+)?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "November 8 at 8:30 am", "October 30, 2026 by 10:30 AM"
      RegExp(r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(?:(\d{4})\s+)?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "on 8th Nov at 8:30 am" or "on 8th Nov by 8:30 am"
      RegExp(r"on\s+(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(?:(\d{4})\s+)?(?:at|by)\s+(\d{1,2})[:\.\s](\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches without the 'at' keyword: "Nov 1, 12:00 PM" or "November 1 12:00 PM"
      RegExp(r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s*(?:(\d{4})\s*)?(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches without the 'at' keyword WITH ORDINALS: "1st November 2025 5.45 pm" or "3rd December 2025 6pm"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s*(?:(\d{4})\s*)?(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches without the 'at' keyword: "31st October 2025 4.00 pm" or "31 Oct 4 pm"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s*(?:(\d{4})\s*)?(\d{1,2})[:\.]?(\d{2})?\s*(am|pm)?", caseSensitive: false),
      // Matches: "nov14 6:00pm", "Nov 14 6:00 PM", "November14 6:00pm"
      RegExp(r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s*(\d{1,2})\s+(\d{1,2})[:\.](\d{2})\s*(am|pm)?", caseSensitive: false),
      // Matches: "14nov 6:00pm", "14 November 6:00pm", "14th Nov 6:00pm"
      RegExp(r"(\d{1,2})(?:st|nd|rd|th)?\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{1,2})[:\.](\d{2})\s*(am|pm)?", caseSensitive: false),
    ];

    _parseMatches(text, dateTimePatterns, candidates, candidatesLog, 'date-time');

    // After Pass 1B, check if we have any valid future candidates.
    futureCandidates = candidates.where((c) => (c['date'] as DateTime).isAfter(now)).toList();
    if (futureCandidates.isNotEmpty) {
      print('--- PASS 1B SUCCESS: Found full date-time match(es). Selecting nearest future date. ---');
      futureCandidates.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      final selected = futureCandidates.first;
      final selectedDate = selected['date'] as DateTime;
      
      candidatesLog.add("\n[PASS 1B - GENERAL TIME] Selected: ${DateFormat('MMM d, yyyy h:mm a').format(selectedDate)} (nearest future date from full match)");
      print('  ✓ Selected nearest future: $selectedDate');
      
      return {'finalDate': selectedDate, 'candidatesLog': candidatesLog};
    }

    // =========================================================================
    // PASS 2: If no full date-time found, search for time-only patterns.
    // =========================================================================
    print('\n--- PASS 2: No definitive date found. Searching for time-only patterns. ---');
    final timePatterns = <RegExp>[
      // Matches: "13:52", "09:30", "18:25" (24-hour format)
      RegExp(r"\b([01]?\d|2[0-3]):([0-5]\d)\b"),
      // Matches: "1:52 PM", "10:30 AM", "3 PM" (12-hour format with AM/PM)
      RegExp(r"(\d{1,2}):?(\d{2})?\s*(AM|PM|am|pm)", caseSensitive: false),
    ];

    for (var i = 0; i < timePatterns.length; i++) {
      final pattern = timePatterns[i];
      final matches = pattern.allMatches(text);
      for (final match in matches) {
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
          final result = _toNextOccurrence(hour, minute);
          candidates.add({'date': result, 'pattern': 'time-only ${i+1}', 'match': match.group(0)!});
          candidatesLog.add("Found: ${DateFormat('MMM d, yyyy h:mm a').format(result)}\n  - From: \"${match.group(0)!}\"\n  - Using pattern: #time-only ${i+1}");

        } catch (_) {}
      }
    }

    if (candidates.isEmpty) {
      print('--- PARSING FAILED: No date or time patterns found. ---');
      return null;
    }

    // Recalculate future candidates including time-only matches
    final allFutureCandidates = candidates.where((c) => (c['date'] as DateTime).isAfter(now)).toList();
    
    if (allFutureCandidates.isNotEmpty) {
      allFutureCandidates.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      final selected = allFutureCandidates.first;
      final selectedDate = selected['date'] as DateTime;
      
      candidatesLog.add("\n[PASS 2] Selected: ${DateFormat('MMM d, yyyy h:mm a').format(selectedDate)} (nearest future time)");
      print('  ✓ Selected nearest future from time-only: $selectedDate');
      return {'finalDate': selectedDate, 'candidatesLog': candidatesLog};
    }

    // If no future dates at all, return the latest candidate (closest past)
    candidates.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final selected = candidates.last;
    final selectedDate = selected['date'] as DateTime;
    
    candidatesLog.add("\n[NO FUTURE DATES] Selected: ${DateFormat('MMM d, yyyy h:mm a').format(selectedDate)} (latest past date)");
    print('  ⚠ No future dates; returning latest past: $selectedDate');
    return {'finalDate': selectedDate, 'candidatesLog': candidatesLog};
  }

  void _parseMatches(String text, List<RegExp> patterns, List<Map<String, dynamic>> candidates, List<String> log, String pass) {
    for (var i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        print('  Pattern #$i matched:');

        try {
          String? monthStr;
          int? monthNum;
          int? day;
          int? year;
          int? hour;
          int? minute;
          String? ampm;

          final groupCount = match.groupCount;
          print('  Found match: "${match.group(0)}" (groups: $groupCount)');

          // Special handling for start-time patterns (Pass 1A)
          if (pass == 'start-time') {
            // For start-time patterns, extract date and optional time
            final firstGroup = match.group(1)!;
            
            if (RegExp(r'^\d+$').hasMatch(firstGroup)) {
              // Could be "from 31st October" or "from 31/10/2025"
              final group2 = match.group(2) ?? '';
              
              if (RegExp(r'^[A-Za-z]+$').hasMatch(group2)) {
                // "from 31st October 2025 [9:00 am]"
                day = int.tryParse(firstGroup);
                monthStr = group2;
                year = match.group(3) != null && match.group(3)!.length == 4 ? int.tryParse(match.group(3)!) : null;
                hour = match.group(4) != null ? int.tryParse(match.group(4)!) : null;
                minute = match.group(5) != null ? int.tryParse(match.group(5)!) : null;
                ampm = match.group(6);
                
                // If no time specified for start-time, default to 9:00 AM
                if (hour == null) {
                  hour = 9;
                  minute = 0;
                  ampm = 'am';
                  print('  No time specified for start - defaulting to 9:00 AM');
                }
              } else if (RegExp(r'^\d+$').hasMatch(group2)) {
                // "from 31/10/2025 [9:00 am]"
                day = int.tryParse(firstGroup);
                monthNum = int.tryParse(group2);
                final yRaw = match.group(3);
                if (yRaw != null) {
                  final yNum = int.tryParse(yRaw);
                  if (yNum != null) {
                    year = yNum < 100 ? (yNum >= 70 ? 1900 + yNum : 2000 + yNum) : yNum;
                  }
                }
                hour = match.group(4) != null ? int.tryParse(match.group(4)!) : null;
                minute = match.group(5) != null ? int.tryParse(match.group(5)!) : null;
                ampm = match.group(6);
                
                // If no time specified for start-time, default to 9:00 AM
                if (hour == null) {
                  hour = 9;
                  minute = 0;
                  ampm = 'am';
                  print('  No time specified for start - defaulting to 9:00 AM');
                }
              }
            }
            
            // Process the start-time candidate
            if (day != null && hour != null) {
              int? month;
              if (monthStr != null) {
                final months = ['january', 'february', 'march', 'april', 'may', 'june', 
                              'july', 'august', 'september', 'october', 'november', 'december'];
                final monthLower = monthStr.toLowerCase();
                final monthIndex = months.indexWhere((m) => monthLower.startsWith(m.substring(0, 3)));
                if (monthIndex >= 0) {
                  month = monthIndex + 1;
                }
              } else if (monthNum != null) {
                month = monthNum;
              }
              
              if (month != null && month >= 1 && month <= 12) {
                if (year == null) {
                  final now = DateTime.now();
                  year = now.year;
                  final testDate = DateTime(year, month, day);
                  if (testDate.isBefore(DateTime(now.year, now.month, now.day))) {
                    year++;
                  }
                }
                
                if (ampm != null) {
                  final ampmLower = ampm.toLowerCase();
                  if (ampmLower == 'pm' && hour < 12) {
                    hour += 12;
                  } else if (ampmLower == 'am' && hour == 12) {
                    hour = 0;
                  }
                }
                
                final result = DateTime(year, month, day, hour, minute ?? 0);
                print('  ✓ START TIME candidate added: $result');
                candidates.add({'date': result, 'pattern': i, 'match': match.group(0)!});
                log.add("Found: ${DateFormat('MMM d, yyyy h:mm a').format(result)}\n  - From: \"${match.group(0)!}\"\n  - Using pattern: #$pass-$i (START TIME)");
              }
            }
            continue; // Skip the regular parsing logic below
          }

          // Regular pattern parsing (for non-start-time patterns)
          final firstGroup = match.group(1)!;
          
          // Special handling for noon/midnight patterns
          if (groupCount >= 4 && (match.group(groupCount)?.toLowerCase() == 'noon' || match.group(groupCount)?.toLowerCase() == 'midnight')) {
            day = int.tryParse(firstGroup);
            monthStr = match.group(2);
            year = match.group(3) != null && match.group(3)!.length == 4 ? int.tryParse(match.group(3)!) : null;
            final noonOrMidnight = match.group(groupCount)!.toLowerCase();
            if (noonOrMidnight == 'noon') {
              hour = 12;
              minute = 0;
              ampm = 'pm';
            } else {  // midnight
              hour = 0;
              minute = 0;
              ampm = 'am';
            }
            print('  Noon/Midnight pattern: day=$day, month=$monthStr, year=$year, hour=$hour, minute=$minute');
          } else if (RegExp(r'^\d+$').hasMatch(firstGroup)) {
            // First group is a number - could be day
            if (groupCount >= 4) {
              final group2 = match.group(2) ?? '';
              if (RegExp(r'^[A-Za-z]+$').hasMatch(group2)) {
                // This is day + month pattern
                day = int.parse(firstGroup);
                monthStr = group2;
                
                // Check which pattern matched based on remaining groups
                if (groupCount == 5) {
                  // Pattern: "DATE: 14TH NOV ... TIME: 6:00 PM" or "14nov 6:00pm"
                  hour = int.tryParse(match.group(3) ?? '');
                  minute = int.tryParse(match.group(4) ?? '');
                  ampm = match.group(5);
                } else if (groupCount >= 6) {
                  // Pattern with 'at' or year: "14th Nov at 6:00pm"
                  final lower = match.group(0)!.toLowerCase();
                  final hasPreposition = lower.contains(' at ') || lower.contains(' by ');
                  if (hasPreposition) {
                    year = match.group(3) != null && match.group(3)!.length == 4 ? int.tryParse(match.group(3)!) : null;
                    hour = int.tryParse(match.group(4) ?? '');
                    minute = match.group(5) != null ? int.tryParse(match.group(5)!) : 0;
                    ampm = match.group(6);
                  } else { 
                    // Handle optional year without 'at': e.g., "31 Oct 2025 4:00 pm"
                    if (match.group(3) != null && match.group(3)!.length == 4) {
                      year = int.tryParse(match.group(3)!);
                      hour = int.tryParse(match.group(4) ?? '');
                      minute = int.tryParse(match.group(5) ?? '');
                      ampm = match.group(6);
                    } else {
                      hour = int.tryParse(match.group(3) ?? '');
                      minute = int.tryParse(match.group(4) ?? '');
                      ampm = match.group(5);
                    }
                  }
                }
              } else if (RegExp(r'^\d+$').hasMatch(group2)) {
                // Numeric date pattern: dd[./-]mm[./-]yyyy ... (at|by) hh:mm am/pm
                // Assume international format (day.month.year)
                day = int.tryParse(firstGroup);
                monthNum = int.tryParse(group2);
                // Year may be 2 or 4 digits
                final yRaw = match.group(3);
                if (yRaw != null) {
                  final yNum = int.tryParse(yRaw);
                  if (yNum != null) {
                    year = yNum < 100 ? (yNum >= 70 ? 1900 + yNum : 2000 + yNum) : yNum;
                  }
                }
                hour = int.tryParse(match.group(4) ?? '');
                minute = match.group(5) != null ? int.tryParse(match.group(5)!) : 0;
                ampm = match.group(6);
                print('  Numeric date: day=$day, month=$monthNum, year=$year, hour=$hour, minute=$minute, ampm=$ampm');
              }
            }
          } else if (RegExp(r'^[A-Za-z]+$').hasMatch(firstGroup)) {
            // First group is text - month name
            monthStr = firstGroup;

            if (groupCount >= 5) {
              day = int.tryParse(match.group(2) ?? '');

              // Check if there's 'at' or 'by' keyword
              final lower = match.group(0)!.toLowerCase();
              final hasPreposition = lower.contains(' at ') || lower.contains(' by ');
              if (hasPreposition) {
                year = match.group(3) != null && match.group(3)!.length == 4 ? int.tryParse(match.group(3)!) : null;
                hour = int.tryParse(match.group(4) ?? '');
                minute = match.group(5) != null ? int.tryParse(match.group(5)!) : 0;
                ampm = match.group(6);
              } else {
                // Pattern may include optional year before time: "Nov 1, 2025 12:00 PM" or "Nov 1 12:00 PM"
                if (groupCount >= 6 && match.group(3) != null && match.group(3)!.length == 4) {
                  year = int.tryParse(match.group(3)!);
                  hour = int.tryParse(match.group(4) ?? '');
                  minute = int.tryParse(match.group(5) ?? '');
                  ampm = match.group(6);
                } else {
                  // Pattern like "Nov14 6:00pm" or "Nov 14 6:00pm"
                  hour = int.tryParse(match.group(3) ?? '');
                  minute = int.tryParse(match.group(4) ?? '');
                  ampm = match.group(5);
                }
              }
            }
          }

          if (day != null && hour != null && (monthStr != null || monthNum != null)) {
            int? month;
            if (monthStr != null) {
              // Parse month name (support both full and abbreviated)
              final months = ['january', 'february', 'march', 'april', 'may', 'june', 
                            'july', 'august', 'september', 'october', 'november', 'december'];
              final monthLower = monthStr.toLowerCase();
              final monthIndex = months.indexWhere((m) => monthLower.startsWith(m.substring(0, 3)));
              if (monthIndex >= 0) {
                month = monthIndex + 1; // Convert to 1-based month
              }
            } else if (monthNum != null) {
              month = monthNum;
            }
            
            if (month != null && month >= 1 && month <= 12) {
              
              // If no year provided, determine based on month and day
              if (year == null) {
                final now = DateTime.now();
                year = now.year;
                
                // Create a test date to check if it's in the past
                final testDate = DateTime(year, month, day);
                
                // If the date is in the past, use next year
                if (testDate.isBefore(DateTime(now.year, now.month, now.day))) {
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
              print('  ✓ Candidate added: $result (month=$month, day=$day, year=$year, time=$hour:${minute ?? 0})');
              candidates.add({'date': result, 'pattern': i, 'match': match.group(0)!});
              log.add("Found: ${DateFormat('MMM d, yyyy h:mm a').format(result)}\n  - From: \"${match.group(0)!}\"\n  - Using pattern: #$pass-$i");
            }
          }
        } catch (e) {
          print('  ✗ Error parsing match: $e');
          // swallow and continue to next match
        }
      }
    }
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


