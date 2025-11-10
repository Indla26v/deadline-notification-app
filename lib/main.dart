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
  
  // Initialize in-app alarm service
  await InAppAlarmService().initialize();
  
  // Initialize background email checking
  await BackgroundEmailService.initialize();
  await BackgroundEmailService.registerPeriodicTask();
  // REMOVED: registerOneTimeTask() to prevent vibration on app launch
  // The immediate check was causing notification vibrations when app starts
  // Background sync will happen after 15 minutes instead
  
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
  
  // Run initial database sync after services are initialized
  await InAppAlarmService().syncWithDatabase();
  
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


