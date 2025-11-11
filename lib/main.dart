import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_page.dart';
import 'screens/email_detail_screen.dart';
import 'services/background_email_service.dart';
import 'services/alarm_service.dart';
import 'services/in_app_alarm_service.dart';
import 'services/email_database.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Reset and configure Android notification channels BEFORE any notifications are used
  final androidImpl = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    try {
      // Delete likely existing channels to avoid inheriting old vibration settings
      final channelsToDelete = <String>[
        'miscellaneous', // plugin default
        'new_email_channel',
        'very_important_email_channel',
        'bell_new_emails',
        'confirmation_channel',
        'test_channel',
        'bell_fallback',
        'WorkManager', // AndroidX WorkManager default channel
      ];
      for (final id in channelsToDelete) {
        try { await androidImpl.deleteNotificationChannel(id); } catch (_) {}
      }
      
      // Recreate the channels we use with vibration disabled by default
      const channelsToCreate = <AndroidNotificationChannel>[
        AndroidNotificationChannel(
          'new_email_channel',
          'Bell - New Emails',
          description: 'Notifications for new emails fetched in background',
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          'very_important_email_channel',
          'Bell - Very Important Emails',
          description: 'Notifications for emails matching your profile',
          importance: Importance.max,
          playSound: true,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          'bell_new_emails',
          'Bell - New Email Alerts',
          description: 'General bell email notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          'confirmation_channel',
          'Bell - Confirmations',
          description: 'Alarm set confirmations and app system notices',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          'test_channel',
          'Bell - Test',
          description: 'Diagnostic test notifications',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          'WorkManager',
          'WorkManager',
          description: 'AndroidX WorkManager background tasks',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      ];
      for (final ch in channelsToCreate) {
        await androidImpl.createNotificationChannel(ch);
      }
      // IMPORTANT: We intentionally do NOT create 'bell_alarm_channel' here.
      // The native AlarmService will create it with vibration enabled only when an actual alarm rings.
    } catch (e) {
      // Non-fatal; proceed even if channel ops fail
      // ignore: avoid_print
      print('Channel reset error: $e');
    }
  }
  
  // --- VIBRATION DEBUG: Disabling In-App Alarm Service ---
  /*
  // Initialize in-app alarm service
  await InAppAlarmService().initialize();
  */
  // --- END VIBRATION DEBUG ---
  
  // Initialize background email checking
  await BackgroundEmailService.initialize();
  await BackgroundEmailService.registerPeriodicTask();
  
  // Initialize notifications for background emails
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        // Handle email notification click
        final email = await EmailDatabase.instance.getEmailById(payload);
        if (email != null && navigatorKey.currentContext != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => EmailDetailScreen(email: email),
            ),
          );
        }
      }
    },
  );
  
  // Set up alarm notification click callback
  AlarmService.notificationClickCallback = (String emailId) async {
    print('Alarm notification clicked for email: $emailId');
    
    // Get email from database
    final email = await EmailDatabase.instance.getEmailById(emailId);
    if (email != null && navigatorKey.currentContext != null) {
      // Navigate to email detail screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => EmailDetailScreen(email: email),
        ),
      );
    } else {
      print('Email not found in database or no context available');
    }
  };
  
  runApp(MailAlarmApp());
}

class MailAlarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mail Alarm',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}


