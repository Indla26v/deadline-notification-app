import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xl;
import 'gmail_service.dart';
import 'profile_service.dart';
import 'email_database.dart';
import '../models/user_profile.dart';
import 'package:google_sign_in/google_sign_in.dart';

const String emailCheckTaskName = 'emailCheckTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _checkForNewEmails();
      return Future.value(true);
    } catch (e) {
      print('Background email check failed: $e');
      return Future.value(false);
    }
  });
}

Future<void> _checkForNewEmails() async {
  final prefs = await SharedPreferences.getInstance();
  final lastEmailId = prefs.getString('lastEmailId');
  
  try {
    // Load user profile
    final profileService = ProfileService();
    final userProfile = await profileService.loadProfile();
    
    // Try to get existing credentials
    final googleSignIn = GoogleSignIn(scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'email',
      'profile',
      'openid',
    ]);
    
    // Sign in silently (will only work if user is already signed in)
    final account = await googleSignIn.signInSilently();
    if (account == null) {
      print('User not signed in, skipping background check');
      return;
    }
    
    final gmailService = GmailService();
    final client = await gmailService.signInAndGetClient();
    
    if (client == null) {
      print('Failed to get auth client');
      return;
    }
    
    // Fetch latest emails
    final emails = await gmailService.fetchEmails(client);
    
    // Save all fetched emails to database
    final emailDb = EmailDatabase.instance;
    await emailDb.insertEmails(emails);
    print('Background: Cached ${emails.length} emails to database');
    
    if (emails.isNotEmpty) {
      final latestEmail = emails.first;
      
      // Check if this is a new email
      if (lastEmailId == null || latestEmail.id != lastEmailId) {
        // Check if email is very important (contains user profile)
        bool isVeryImportant = false;
        if (userProfile.isComplete) {
          isVeryImportant = userProfile.matchesEmail(latestEmail.subject, latestEmail.body, latestEmail.sender);
          
          // Also check Excel attachments if any
          if (!isVeryImportant && latestEmail.attachments.isNotEmpty) {
            for (var attachment in latestEmail.attachments) {
              if (_isExcelFile(attachment.filename)) {
                final matchFound = await _checkExcelForProfile(
                  client, 
                  latestEmail.id, 
                  attachment.attachmentId, 
                  userProfile
                );
                if (matchFound) {
                  isVeryImportant = true;
                  break;
                }
              }
            }
          }
        }
        
        // Show notification for new email
        await _showNewEmailNotification(
          latestEmail.id,
          latestEmail.sender, 
          latestEmail.subject,
          latestEmail.snippet.isNotEmpty ? latestEmail.snippet : latestEmail.body,
          isVeryImportant,
        );
        
        // Update last email ID
        await prefs.setString('lastEmailId', latestEmail.id);
        
        // Store if email is very important
        if (isVeryImportant) {
          final importantEmails = prefs.getStringList('veryImportantEmails') ?? [];
          if (!importantEmails.contains(latestEmail.id)) {
            importantEmails.add(latestEmail.id);
            await prefs.setStringList('veryImportantEmails', importantEmails);
          }
          
          // Update email in database with important flag
          latestEmail.isVeryImportant = true;
          await emailDb.updateEmail(latestEmail);
        }
      }
    }
  } catch (e) {
    print('Error checking emails: $e');
  }
}

bool _isExcelFile(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.xlsx') || 
         lower.endsWith('.xls') || 
         lower.endsWith('.xlsm') ||
         lower.endsWith('.csv');
}

Future<bool> _checkExcelForProfile(
  dynamic client, 
  String emailId, 
  String attachmentId,
  UserProfile userProfile,
) async {
  try {
    final gmailService = GmailService();
    final attachmentData = await gmailService.downloadAttachment(
      client, 
      emailId, 
      attachmentId,
    );
    
    // Save to temp file
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/temp_excel_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(attachmentData);
    
    // Parse Excel
    final bytes = file.readAsBytesSync();
    final excel = xl.Excel.decodeBytes(bytes);
    
    // Search all sheets for profile data
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;
      
      for (var row in sheet.rows) {
        final rowText = row.map((cell) => cell?.value?.toString() ?? '').join(' ').toLowerCase();
        
        // Check for matches
        final nameMatch = userProfile.name.isNotEmpty && 
                         rowText.contains(userProfile.name.toLowerCase());
        final regNoMatch = userProfile.registrationNumber.isNotEmpty && 
                          rowText.contains(userProfile.registrationNumber.toLowerCase());
        final primaryEmailMatch = userProfile.primaryEmail.isNotEmpty && 
                                 rowText.contains(userProfile.primaryEmail.toLowerCase());
        final secondaryEmailMatch = userProfile.secondaryEmail.isNotEmpty && 
                                   rowText.contains(userProfile.secondaryEmail.toLowerCase());
        
        if (regNoMatch || (nameMatch && (primaryEmailMatch || secondaryEmailMatch))) {
          // Clean up temp file
          await file.delete();
          return true;
        }
      }
    }
    
    // Clean up temp file
    await file.delete();
    return false;
  } catch (e) {
    print('Error checking Excel file: $e');
    return false;
  }
}

Future<void> _showNewEmailNotification(String emailId, String sender, String subject, String body, bool isVeryImportant) async {
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await notifications.initialize(initSettings);
  
  // Create Outlook-style expandable notification
  final BigTextStyleInformation bigTextStyle = BigTextStyleInformation(
    body,
    htmlFormatBigText: false,
    contentTitle: subject,
    htmlFormatContentTitle: false,
    summaryText: sender,
    htmlFormatSummaryText: false,
  );
  
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    isVeryImportant ? 'very_important_email_channel' : 'new_email_channel',
    isVeryImportant ? 'Bell - Very Important' : 'Bell - New Emails',
    channelDescription: isVeryImportant 
        ? 'Notifications for emails containing your profile information'
        : 'Notifications for new emails',
    importance: isVeryImportant ? Importance.max : Importance.high,
    priority: isVeryImportant ? Priority.max : Priority.high,
    styleInformation: bigTextStyle,
    icon: '@mipmap/ic_launcher',
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    color: isVeryImportant ? const Color(0xFFFF0000) : const Color(0xFFFFC107), // Red for important, Bell gold for normal
    playSound: true,
    enableVibration: false, // Disable vibration for background notifications
    when: DateTime.now().millisecondsSinceEpoch,
    showWhen: true,
    category: AndroidNotificationCategory.email,
    visibility: NotificationVisibility.private,
  );
  
  final NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
  
  await notifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    isVeryImportant ? '⭐ Bell - New Email' : 'Bell • Now 🔔',
    subject,
    notificationDetails,
    payload: emailId, // Add email ID for navigation
  );
}

class BackgroundEmailService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }
  
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      'email-check',
      emailCheckTaskName,
      frequency: const Duration(minutes: 15), // Android minimum is 15 minutes
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: const Duration(seconds: 10), // Start checking soon after app launch
    );
  }
  
  static Future<void> registerOneTimeTask() async {
    // For immediate check when app starts
    await Workmanager().registerOneOffTask(
      'email-check-immediate',
      emailCheckTaskName,
      initialDelay: const Duration(seconds: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
  
  static Future<void> cancelPeriodicTask() async {
    await Workmanager().cancelByUniqueName('email-check');
  }
}
