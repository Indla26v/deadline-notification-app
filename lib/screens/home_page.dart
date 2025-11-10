import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/email_model.dart';
import '../models/user_profile.dart';
import '../services/gmail_service.dart';
import '../services/alarm_service.dart';
import '../services/in_app_alarm_service.dart';
import '../services/profile_service.dart';
import '../services/email_database.dart';
import '../services/websocket_service.dart';
import '../widgets/bell_icon.dart';
import '../widgets/parser_results_dialog.dart';
import '../widgets/success_alert_bar.dart';
import 'email_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'alarm_management_screen.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GmailService _gmailService = GmailService();
  final AlarmService _alarmService = AlarmService();
  final InAppAlarmService _inAppAlarmService = InAppAlarmService();
  final ProfileService _profileService = ProfileService();
  final EmailDatabase _emailDatabase = EmailDatabase.instance;
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  
  auth.AuthClient? _client;
  bool _loading = false;
  bool _loadingMore = false;
  List<EmailModel> _emails = <EmailModel>[];
  List<EmailModel> _searchResults = <EmailModel>[];
  String? _nextPageToken;
  String _currentFilter = 'all'; // 'all', 'with_alarms', or 'very_important'
  UserProfile _userProfile = UserProfile();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _searchDebounce;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _alarmService.initialize();
    _alarmService.requestAndroidPermissions();
    _scrollController.addListener(_onScroll);
    // Load user profile and auto sign-in
    _loadProfileAndSignIn();
    // Clean old emails (older than 60 days)
    _cleanOldEmails();
    // Initialize WebSocket connection
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    try {
      // Wait a bit for sign-in to complete
      await Future.delayed(const Duration(seconds: 2));
      
      // Get user email from GoogleSignIn
      final account = await _gmailService.getCurrentUser();
      if (account != null && account.email.isNotEmpty) {
        print('Initializing WebSocket for ${account.email}');
        
        // Connect to WebSocket (note: this requires a backend service)
        // For now, this will fail gracefully if no backend is set up
        try {
          await _wsService.connect(account.email);
          
          // Listen for new email notifications
          _wsService.messages.listen((message) {
            if (message['type'] == 'new_email' && mounted) {
              print('WebSocket: New email notification received');
              // Show notification snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.mail, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'New email: ${message['subject'] ?? 'No subject'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.blue.shade700,
                  action: SnackBarAction(
                    label: 'Refresh',
                    textColor: Colors.white,
                    onPressed: _refreshEmails,
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
              // Auto-refresh emails
              _refreshEmails();
            } else if (message['type'] == 'error' && mounted) {
              print('WebSocket error: ${message['message']}');
            }
          });
          
          // Subscribe to new email events
          _wsService.subscribeToNewEmails(account.email);
        } catch (e) {
          print('WebSocket connection failed (this is expected without a backend): $e');
        }
      }
    } catch (e) {
      print('WebSocket initialization error: $e');
    }
  }

  Future<void> _cleanOldEmails() async {
    try {
      await _emailDatabase.deleteOldEmails(60); // Keep emails for 2 months
      final count = await _emailDatabase.getEmailCount();
      print('Email database: $count emails cached');
    } catch (e) {
      print('Error cleaning old emails: $e');
    }
  }

  Future<void> _loadProfileAndSignIn() async {
    // Load profile first
    _userProfile = await _profileService.loadProfile();
    
    // Load cached emails first for instant display
    await _loadCachedEmails();
    
    // Check if already signed in and get client without showing UI
    try {
      final client = await _gmailService.signInAndGetClient();
      if (client != null && mounted) {
        setState(() {
          _client = client;
        });
      }
    } catch (e) {
      print('Silent sign-in failed: $e');
    }
    
    // Then fetch fresh emails from server in background (don't await)
    _autoSignIn();
  }

  Future<void> _loadCachedEmails() async {
    try {
      // Load ALL cached emails from database (not just 100)
      final cachedEmails = await _emailDatabase.getAllEmails();
      if (cachedEmails.isNotEmpty && mounted) {
        setState(() {
          _emails = cachedEmails;
          // If we have cached emails, we probably have a valid token for the last one
          if (cachedEmails.isNotEmpty) {
            _nextPageToken = cachedEmails.last.pageToken;
          }
        });
        print('Loaded ${cachedEmails.length} cached emails from database');
      }
    } catch (e) {
      print('Error loading cached emails: $e');
    }
  }

  Future<void> _autoSignIn() async {
    if (_loading) return; // Prevent multiple simultaneous loads
    
    // Don't show loading indicator if we have cached emails
    if (_emails.isEmpty) {
      setState(() => _loading = true);
    }
    
    try {
      _client = await _gmailService.signInAndGetClient();
      if (_client != null) {
        // Check if this is the first time signing in
        final prefs = await SharedPreferences.getInstance();
        final isFirstTime = !(prefs.getBool('hasSignedInBefore') ?? false);
        
        // Save signed-in state
        await prefs.setBool('isSignedIn', true);
        
        final emails = await _gmailService.fetchEmails(_client!);
        
        // If first time and profile is complete, do a full scan of all emails
        if (isFirstTime && _userProfile.isComplete) {
          print('First-time sign-in detected - performing full email scan for profile matches...');
          await _performFirstTimeProfileScan(emails);
          await prefs.setBool('hasSignedInBefore', true);
        } else {
          await _markImportantEmails(emails);
        }
        
        // Save to database
        await _emailDatabase.insertEmails(emails);
        
        if (mounted) {
          setState(() {
            // If we have cached emails, merge them preserving local state
            if (_emails.isNotEmpty) {
              final emailMap = {for (var e in _emails) e.id: e};
              
              // Update existing emails with fresh data from Gmail
              for (var newEmail in emails) {
                if (emailMap.containsKey(newEmail.id)) {
                  // Preserve local state (hasAlarm, alarmTimes) but update isUnread from Gmail
                  final cachedEmail = emailMap[newEmail.id]!;
                  newEmail.hasAlarm = cachedEmail.hasAlarm;
                  newEmail.alarmTimes = cachedEmail.alarmTimes;
                  newEmail.isVeryImportant = cachedEmail.isVeryImportant;
                  emailMap[newEmail.id] = newEmail;
                } else {
                  // New email
                  emailMap[newEmail.id] = newEmail;
                }
              }
              
              _emails = emailMap.values.toList();
            } else {
              _emails = emails;
            }
            _nextPageToken = emails.isNotEmpty ? emails.last.pageToken : null;
          });
          print('Emails loaded: ${_emails.length}, Next token: $_nextPageToken');
          
          // If first time, open profile page to let user update details
          if (isFirstTime) {
            _openProfilePageForFirstTime();
          }
        }
      }
    } catch (e) {
      // Handle authentication errors
      print('Auto sign-in error: $e');
      if (e.toString().contains('invalid_token') || 
          e.toString().contains('Access was denied')) {
        // Token expired, clear client and saved state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isSignedIn', false);
        
        if (mounted) {
          setState(() => _client = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please sign in again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Perform a comprehensive scan of all emails for profile matches on first sign-in
  Future<void> _performFirstTimeProfileScan(List<EmailModel> emails) async {
    if (!_userProfile.isComplete) {
      print('Profile not complete - skipping first-time scan');
      return;
    }
    
    print('Starting first-time profile scan of ${emails.length} emails...');
    final prefs = await SharedPreferences.getInstance();
    final matchedIds = <String>[];
    int textMatches = 0;
    int excelMatches = 0;
    
    // Check all emails for text matches
    for (var email in emails) {
      final matched = _userProfile.matchesEmail(email.subject, email.body, email.sender);
      if (matched) {
        email.isVeryImportant = true;
        matchedIds.add(email.id);
        textMatches++;
        print('✓ Text match: ${email.subject}');
      }
    }
    
    // Check Excel attachments
    for (var email in emails) {
      if (!email.isVeryImportant && email.attachments.isNotEmpty && _client != null) {
        for (var attachment in email.attachments) {
          if (_isExcelFile(attachment.filename)) {
            final matchFound = await _checkExcelForProfile(email.id, attachment.attachmentId);
            if (matchFound) {
              email.isVeryImportant = true;
              matchedIds.add(email.id);
              excelMatches++;
              print('✓ Excel match: ${email.subject}');
              break;
            }
          }
        }
      }
    }
    
    // Save all matched email IDs
    await prefs.setStringList('veryImportantEmails', matchedIds);
    
    print('First-time scan complete: $textMatches text matches, $excelMatches Excel matches, ${matchedIds.length} total');
    
    // Show summary to user
    if (mounted && matchedIds.isNotEmpty) {
      showSuccessAlert(
        context,
        '✓ Found ${matchedIds.length} emails matching your profile!',
      );
    }
  }

  void _openProfilePageForFirstTime() {
    // Delay slightly to let the UI settle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.green),
              SizedBox(width: 8),
              Text('Welcome to Bell!'),
            ],
          ),
          content: const Text(
            'This is your first time signing in.\n\n'
            'Please update your profile details so Bell can automatically detect '
            'important emails containing your information.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
                if (result == true) {
                  // Profile was saved, reload and refresh emails
                  _userProfile = await _profileService.loadProfile();
                  _refreshEmails();
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Setup Profile'),
            ),
          ],
        ),
      );
    });
  }

  // Mark emails as very important if they contain user's profile info
  Future<void> _markImportantEmails(List<EmailModel> emails) async {
    // Load previously identified important emails from storage
    final prefs = await SharedPreferences.getInstance();
    final storedImportantIds = prefs.getStringList('veryImportantEmails') ?? [];
    
    // Apply stored important flags FIRST (persist across restarts)
    for (var email in emails) {
      if (storedImportantIds.contains(email.id)) {
        email.isVeryImportant = true;
      }
    }
    
    if (!_userProfile.isComplete) return;
    
    // Then check text content for newly fetched emails
    for (var email in emails) {
      if (!email.isVeryImportant) { // Only check if not already marked
        final matched = _userProfile.matchesEmail(email.subject, email.body, email.sender);
        if (matched) {
          print('✓ Text match found for: ${email.subject}');
          email.isVeryImportant = true;
        }
      }
    }
    
    // Then check Excel attachments for emails not already marked
    for (var email in emails) {
      if (!email.isVeryImportant && email.attachments.isNotEmpty && _client != null) {
        for (var attachment in email.attachments) {
          if (_isExcelFile(attachment.filename)) {
            final matchFound = await _checkExcelForProfile(email.id, attachment.attachmentId);
            if (matchFound) {
              email.isVeryImportant = true;
              break;
            }
          }
        }
      }
    }
    
    // Store newly identified important emails
    final updatedImportantIds = emails
        .where((e) => e.isVeryImportant)
        .map((e) => e.id)
        .toList();
    
    // Merge with existing IDs (avoid duplicates)
    final mergedIds = {...storedImportantIds, ...updatedImportantIds}.toList();
    await prefs.setStringList('veryImportantEmails', mergedIds);
    
    // Get list of emails that already have auto-alarms set
    final autoAlarmIds = prefs.getStringList('autoAlarmEmails') ?? [];
    
    // Auto-set alarms for very important emails (20 minutes before detected time)
    // Only set if alarm hasn't been set before
    for (var email in emails) {
      if (email.isVeryImportant && !email.hasAlarm && !autoAlarmIds.contains(email.id)) {
        final parseResult = _alarmService.parseTimeFromText('${email.subject}\n${email.body}');
        final detectedTime = parseResult?['finalDate'] as DateTime?;
        if (detectedTime != null && detectedTime.isAfter(DateTime.now().add(const Duration(minutes: 20)))) {
          // Set alarm 20 minutes before the detected time
          final alarmTime = detectedTime.subtract(const Duration(minutes: 20));
          try {
            await _inAppAlarmService.scheduleAlarm(
              emailId: email.id,
              subject: email.subject,
              sender: email.sender,
              scheduledTime: alarmTime,
              emailLink: email.link,
            );
            email.hasAlarm = true;
            email.alarmTimes = [alarmTime];
            
            // Track that we've set auto-alarm for this email
            autoAlarmIds.add(email.id);
            await prefs.setStringList('autoAlarmEmails', autoAlarmIds);
          } catch (e) {
            print('Failed to auto-set alarm for important email: $e');
          }
        }
      }
    }
  }

  bool _isExcelFile(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.xlsx') || 
           lower.endsWith('.xls') || 
           lower.endsWith('.xlsm') ||
           lower.endsWith('.csv');
  }

  Future<bool> _checkExcelForProfile(String emailId, String attachmentId) async {
    if (_client == null) return false;
    
    try {
      final gmailService = GmailService();
      final attachmentData = await gmailService.downloadAttachment(
        _client!, 
        emailId, 
        attachmentId,
      );
      
      // Parse Excel inline without saving (for memory efficiency)
      final excel = xl.Excel.decodeBytes(attachmentData);
      
      // Prepare profile data for matching (handle various formats)
      final nameParts = _userProfile.name.trim().split(RegExp(r'\s+'))
          .where((p) => p.length > 2)
          .map((p) => p.toLowerCase())
          .toList();
      
      final regNoVariants = _userProfile.registrationNumber.isNotEmpty ? [
        _userProfile.registrationNumber.toLowerCase(),
        _userProfile.registrationNumber.toLowerCase().replaceAll(' ', ''),
        _userProfile.registrationNumber.toLowerCase().replaceAll('-', ''),
        _userProfile.registrationNumber.toLowerCase().replaceAll('_', ''),
      ] : [];
      
      final emailUsernames = <String>[];
      if (_userProfile.primaryEmail.isNotEmpty) {
        emailUsernames.add(_userProfile.primaryEmail.toLowerCase());
        emailUsernames.add(_userProfile.primaryEmail.toLowerCase().split('@')[0]);
      }
      if (_userProfile.secondaryEmail.isNotEmpty) {
        emailUsernames.add(_userProfile.secondaryEmail.toLowerCase());
        emailUsernames.add(_userProfile.secondaryEmail.toLowerCase().split('@')[0]);
      }
      
      // Search all sheets for profile data
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        
        for (var row in sheet.rows) {
          final rowText = row.map((cell) => cell?.value?.toString() ?? '').join(' ').toLowerCase();
          
          // Count matches for more reliable detection
          int nameMatchCount = 0;
          for (final part in nameParts) {
            if (rowText.contains(part)) {
              nameMatchCount++;
            }
          }
          
          // Check registration number variants
          bool regNoMatch = regNoVariants.any((variant) => rowText.contains(variant));
          
          // Check email matches
          bool emailMatch = emailUsernames.any((email) => rowText.contains(email));
          
          // Match criteria:
          // 1. Registration number match (most reliable)
          // 2. At least 2 name parts + email match
          // 3. All name parts match (for full names)
          if (regNoMatch || 
              (nameMatchCount >= 2 && emailMatch) ||
              (nameParts.isNotEmpty && nameMatchCount == nameParts.length)) {
            print('Excel match found: regNo=$regNoMatch, nameCount=$nameMatchCount, email=$emailMatch');
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking Excel file: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Only load more when viewing "All" tab
    if (_currentFilter == 'all' && 
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _nextPageToken != null && _client != null) {
        _loadMoreEmails();
      }
    }
  }

  Future<void> _signInAndLoad() async {
    setState(() => _loading = true);
    try {
      _client = await _gmailService.signInAndGetClient();
      if (_client != null) {
        final emails = await _gmailService.fetchEmails(_client!);
        _markImportantEmails(emails);
        setState(() {
          _emails = emails;
          _nextPageToken = emails.isNotEmpty ? emails.last.pageToken : null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in or fetch failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreEmails() async {
    if (_client == null || _nextPageToken == null || _loadingMore) return;
    
    print('Loading more emails with token: $_nextPageToken');
    setState(() => _loadingMore = true);
    
    try {
      final moreEmails = await _gmailService.fetchEmails(_client!, pageToken: _nextPageToken);
      print('Fetched ${moreEmails.length} more emails');
      
      // DON'T mark important here - just save and display
      // Important marking should only happen on initial load or refresh
      
      // Save to database
      await _emailDatabase.insertEmails(moreEmails);
      
      if (mounted) {
        setState(() {
          // Append new emails to existing list
          _emails.addAll(moreEmails);
          _nextPageToken = moreEmails.isNotEmpty ? moreEmails.last.pageToken : null;
        });
        print('Total emails now: ${_emails.length}, Next token: $_nextPageToken');
      }
    } catch (e) {
      print('Error loading more emails: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load more emails: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshEmails() async {
    if (_client == null) return;
    setState(() => _loading = true);
    try {
      _userProfile = await _profileService.loadProfile(); // Reload profile
      final emails = await _gmailService.fetchEmails(_client!);
      await _markImportantEmails(emails);
      
      // Save to database
      await _emailDatabase.insertEmails(emails);
      
      // Reload all emails from database
      final allEmails = await _emailDatabase.getAllEmails();
      
      setState(() {
        _emails = allEmails;
        _nextPageToken = emails.isNotEmpty ? emails.last.pageToken : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEmailDetail(EmailModel email) {
    if (_client == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailDetailScreen(
          email: email,
          client: _client!,
        ),
      ),
    );
  }

  Future<void> _testAlarm() async {
    try {
      // Request permissions first
      await _alarmService.requestAndroidPermissions();
      
      // Show an immediate test notification first
      await _alarmService.showImmediateTestNotification();
      
      // Schedule alarm for 30 seconds from now (shorter for faster testing)
      final testTime = DateTime.now().add(const Duration(seconds: 30));
      
      await _alarmService.scheduleAlarm(
        label: 'TEST ALARM',
        scheduledDate: testTime,
        link: 'https://mail.google.com',
      );
      
      if (!mounted) return;
      showSuccessAlert(
        context,
        '✓ Test notification shown\n✓ Alarm set for ${DateFormat('h:mm:ss a').format(testTime)}',
      );
      
      // Also check pending notifications
      final pendingNotifications = await _alarmService.getPendingNotifications();
      print('Pending notifications: $pendingNotifications');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting test alarm: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addAlarm(EmailModel email) async {
    try {
      final text = '${email.subject}\n${email.body}';
      final parseResult = _alarmService.parseTimeFromText(text);
      
      if (parseResult == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid time found in this email.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final scheduled = parseResult['finalDate'] as DateTime?;
      
      if (scheduled == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid time found in this email.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show parser results dialog
      if (!mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ParserResultsDialog(
          parseResult: parseResult,
          emailSubject: email.subject,
          emailBody: email.body.length > 500 
              ? '${email.body.substring(0, 500)}...' 
              : email.body,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      );

      if (confirmed != true || !mounted) return;

      // Check if the time is in the past
      if (scheduled.isBefore(DateTime.now())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot set alarm for past time: ${DateFormat('MMM d, h:mm a').format(scheduled)}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Schedule the alarm using InAppAlarmService
      await _inAppAlarmService.scheduleAlarm(
        emailId: email.id,
        subject: email.subject,
        sender: email.sender,
        scheduledTime: scheduled,
        emailLink: email.link,
      );

      // Mark email as having alarm and set the scheduled time
      if (mounted) {
        setState(() {
          email.hasAlarm = true;
          email.alarmTimes = [scheduled];
        });
        
        // Update in database
        await _emailDatabase.updateEmail(email);

        final dateFormat = DateFormat('MMM d, h:mm a');
        final scheduledStr = dateFormat.format(scheduled);
        
        // Show animated success alert bar
        showSuccessAlert(context, 'Alarm set for $scheduledStr');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting alarm: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAlarm(EmailModel email) async {
    try {
      // Cancel the in-app alarm
      await _inAppAlarmService.cancelAlarm(email.id);
      
      if (mounted) {
        setState(() {
          email.hasAlarm = false;
          email.alarmTimes = [];
        });
        
        // Update in database
        await _emailDatabase.updateEmail(email);

        // Show animated success alert bar
        showSuccessAlert(context, 'Alarm removed successfully');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing alarm: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeFromImportant(EmailModel email) async {
    // Remove from SharedPreferences storage
    final prefs = await SharedPreferences.getInstance();
    final storedImportantIds = prefs.getStringList('veryImportantEmails') ?? [];
    storedImportantIds.remove(email.id);
    await prefs.setStringList('veryImportantEmails', storedImportantIds);
    
    if (mounted) {
      setState(() {
        email.isVeryImportant = false;
      });
      
      // Update in database
      await _emailDatabase.updateEmail(email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Removed from Very Important'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _editAlarm(EmailModel email) async {
    final text = '${email.subject}\n${email.body}';
    final parseResult = _alarmService.parseTimeFromText(text);
    final detectedTime = parseResult?['finalDate'] as DateTime?;
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: detectedTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (selectedDate == null || !mounted) return;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(detectedTime ?? DateTime.now()),
    );
    
    if (selectedTime == null || !mounted) return;
    
    final scheduledDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    await _inAppAlarmService.scheduleAlarm(
      emailId: email.id,
      subject: email.subject,
      sender: email.sender,
      scheduledTime: scheduledDate,
      emailLink: email.link,
    );

    // Mark email as having alarm and replace with the new scheduled time
    setState(() {
      email.hasAlarm = true;
      // Replace the alarm time instead of adding
      email.alarmTimes = [scheduledDate];
    });
    
    // Update in database
    await _emailDatabase.updateEmail(email);

    if (!mounted) return;
    final dateFormat = DateFormat('MMM d, yyyy \'at\' h:mm a');
    final scheduledStr = dateFormat.format(scheduledDate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Alarm scheduled for:\n$scheduledStr'),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    // Perform a database-backed search across cached emails (universal search)
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = <EmailModel>[];
          _isSearching = false;
        });
      }
      return;
    }

    try {
      if (mounted) setState(() => _isSearching = true);
      // Use the EmailDatabase search which performs LIKE across subject/body/sender/snippet
      final results = await _emailDatabase.searchEmails(query, limit: 500);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      print('DB search for "$query": ${results.length} results');
    } catch (e) {
      print('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply filter
    var filteredEmails = _currentFilter == 'with_alarms'
        ? _emails.where((e) => e.hasAlarm).toList()
        : _currentFilter == 'very_important'
            ? _emails.where((e) => e.isVeryImportant).toList()
            : _emails;
    
    // Apply search query: prefer DB-backed results when a query is active
    if (_searchQuery.isNotEmpty) {
      // Use DB search results if available
      final source = _searchResults.isNotEmpty ? _searchResults : <EmailModel>[];
      filteredEmails = source.where((email) {
        if (_currentFilter == 'with_alarms') return email.hasAlarm;
        if (_currentFilter == 'very_important') return email.isVeryImportant;
        return true;
      }).toList();
      print('Search results for "$_searchQuery": ${filteredEmails.length} emails shown (DB results: ${_searchResults.length})');
    }

    return Provider<AlarmService>.value(
      value: _alarmService,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const BellIcon(
                  size: 24,
                  color: Color(0xFFFFC107), // Amber/gold color
                ),
              ),
              const SizedBox(width: 8),
              const Text('Bell'),
            ],
          ),
          actions: [
            // Manage Alarms Button
            IconButton(
              icon: Badge(
                isLabelVisible: _emails.where((e) => e.hasAlarm).isNotEmpty,
                label: Text(
                  '${_emails.where((e) => e.hasAlarm).length}',
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Icons.alarm),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AlarmManagementScreen(),
                  ),
                );
                
                // Refresh emails if alarms were modified
                if (result == true && mounted) {
                  await _loadCachedEmails();
                  setState(() {});
                }
              },
              tooltip: 'Manage Alarms',
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: _showProfileSettings,
              tooltip: 'Profile & Settings',
            ),
          ],
          bottom: _emails.isNotEmpty
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(68),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.7),
                                  Colors.white.withOpacity(0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _currentFilter = 'all'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _currentFilter == 'all'
                                            ? Theme.of(context).primaryColor.withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'All',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: _currentFilter == 'all'
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: _currentFilter == 'all'
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _currentFilter = 'very_important'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _currentFilter == 'very_important'
                                            ? Colors.red.withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            size: 16,
                                            color: _currentFilter == 'very_important'
                                                ? Colors.red
                                                : Colors.grey[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Important (${_emails.where((e) => e.isVeryImportant).length})',
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: _currentFilter == 'very_important'
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: _currentFilter == 'very_important'
                                                    ? Colors.red
                                                    : Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _currentFilter = 'with_alarms'),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _currentFilter == 'with_alarms'
                                            ? Theme.of(context).primaryColor.withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.alarm,
                                            size: 16,
                                            color: _currentFilter == 'with_alarms'
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Alarms (${_emails.where((e) => e.hasAlarm).length})',
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: _currentFilter == 'with_alarms'
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: _currentFilter == 'with_alarms'
                                                    ? Theme.of(context).primaryColor
                                                    : Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _signInAndLoad,
              child: _loading && _emails.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _client == null && _emails.isEmpty
                      ? Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Sign in with Google'),
                            onPressed: _signInAndLoad,
                          ),
                        )
                      : filteredEmails.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No emails match "$_searchQuery"'
                                      : _currentFilter == 'with_alarms'
                                          ? 'No emails with alarms set'
                                          : 'No recent emails',
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 80), // Space for search bar
                                cacheExtent: 1000, // Cache items outside viewport for smoother scrolling
                                itemCount: filteredEmails.length + (_loadingMore && _currentFilter == 'all' ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= filteredEmails.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              
                              final email = filteredEmails[index];
                              return Card(
                                key: ValueKey(email.id), // Help Flutter identify and reuse widgets
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: email.isVeryImportant 
                                    ? Colors.red[50]
                                    : email.hasAlarm 
                                        ? Colors.green[50] 
                                        : email.isUnread 
                                            ? Colors.white  // Unread: white background
                                            : const Color(0xFFF5F5F5), // Read: grey background
                                elevation: email.isVeryImportant ? 4 : (email.isUnread ? 3 : 0),
                                shadowColor: email.isUnread ? Colors.blue.withOpacity(0.3) : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: email.isUnread && !email.isVeryImportant && !email.hasAlarm
                                      ? BorderSide(color: Colors.blue.shade100, width: 1) // Subtle blue border for unread
                                      : BorderSide.none,
                                ),
                                child: InkWell(
                                  onTap: () => _openEmailDetail(email),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (email.isVeryImportant)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star, size: 14, color: Colors.white),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Very Important',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (email.hasAlarm)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [Colors.green.shade400, Colors.green.shade600],
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.green.withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.alarm, size: 16, color: Colors.white),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Alarm Set',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (email.attachments.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.attach_file, size: 14, color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${email.attachments.length}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (email.messageCount > 1)
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.forum, size: 14, color: Colors.white),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${email.messageCount}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                email.subject,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: email.isUnread ? FontWeight.w900 : FontWeight.normal,
                                                  fontSize: 16,
                                                  color: email.isUnread ? Colors.black : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (email.receivedDate != null)
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    DateFormat('MMM d').format(email.receivedDate!),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('h:mm a').format(email.receivedDate!),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email.sender,
                                          style: TextStyle(
                                            fontWeight: email.isUnread ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 14,
                                            color: email.isUnread ? Colors.black87 : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          email.body.trim().isEmpty ? email.snippet : email.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: email.isUnread ? Colors.black87 : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Bottom row: alarm times on left, buttons on right
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Show alarm times as pill badges (bottom-left)
                                            if (email.alarmTimes.isNotEmpty)
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: email.alarmTimes.map((time) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [Colors.green.shade100, Colors.green.shade200],
                                                      ),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(color: Colors.green.shade400, width: 1.5),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.access_time, size: 14, color: Colors.green.shade800),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          DateFormat('MMM d, h:mm a').format(time),
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.green.shade900,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )).toList(),
                                                ),
                                              )
                                            else
                                              const SizedBox.shrink(),
                                            
                                            const SizedBox(width: 8),
                                            
                                            // Action buttons (bottom-right)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              alignment: WrapAlignment.end,
                                              children: [
                                                if (email.isVeryImportant)
                                                  OutlinedButton.icon(
                                                    onPressed: () => _removeFromImportant(email),
                                                    icon: const Icon(Icons.star_outline, size: 14, color: Colors.red),
                                                    label: const Text('Remove Important', style: TextStyle(fontSize: 11, color: Colors.red)),
                                                    style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      side: const BorderSide(color: Colors.red),
                                                    ),
                                                  ),
                                                if (email.hasAlarm)
                                                  OutlinedButton.icon(
                                                    onPressed: () => _editAlarm(email),
                                                    icon: const Icon(Icons.edit_calendar, size: 16),
                                                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                                    style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      side: BorderSide(color: Colors.blue.shade400, width: 1.5),
                                                      foregroundColor: Colors.blue.shade700,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                    ),
                                                  ),
                                                ElevatedButton.icon(
                                                  onPressed: email.hasAlarm 
                                                    ? () => _removeAlarm(email)
                                                    : () => _addAlarm(email),
                                                  icon: Icon(
                                                    email.hasAlarm ? Icons.alarm_off : Icons.alarm_add,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    email.hasAlarm ? 'Remove' : 'Add Alarm',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    backgroundColor: email.hasAlarm ? Colors.red.shade400 : Colors.amber.shade600,
                                                    foregroundColor: Colors.white,
                                                    elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
            ),
            // Animated Search FAB (expands from circular to full-width bar)
            if (_emails.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: _isSearchExpanded ? 80 : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  width: _isSearchExpanded ? null : 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.75),
                              Colors.white.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.9),
                            width: 1.8,
                          ),
                        ),
                        child: _isSearchExpanded
                            ? TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (value) {
                                  // Debounced DB-backed search
                                  _searchDebounce?.cancel();
                                  setState(() {
                                    _searchQuery = value;
                                  });

                                  if (value.trim().isEmpty) {
                                    // Clear results immediately
                                    setState(() {
                                      _searchResults = <EmailModel>[];
                                      _isSearching = false;
                                    });
                                    return;
                                  }

                                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                    _performSearch(value);
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search all emails...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.grey[700],
                                    size: 24,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey[700],
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isSearchExpanded = false;
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _searchResults = <EmailModel>[];
                                        _isSearching = false;
                                      });
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              )
                            : Center(
                                child: IconButton(
                                  icon: Icon(
                                    Icons.search,
                                    color: Colors.grey[700],
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearchExpanded = true;
                                    });
                                  },
                                  tooltip: 'Search emails',
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            // Scroll to top button with same glassy effect
            if (_emails.isNotEmpty)
              Positioned(
                bottom: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_upward,
                            color: Colors.grey[700],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfileSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            SizedBox(width: 8),
            Text('Profile & Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(_client != null ? 'Signed in with Google' : 'Not signed in'),
            const SizedBox(height: 16),
            // User Profile Section
            if (_userProfile.isComplete) ...[
              Text('Name: ${_userProfile.name}', style: const TextStyle(fontSize: 13)),
              Text('Reg No: ${_userProfile.registrationNumber}', style: const TextStyle(fontSize: 13)),
            ] else
              const Text('Profile not set up', style: TextStyle(color: Colors.orange, fontSize: 13)),
            const SizedBox(height: 24),
            const Text(
              'Statistics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Total Emails: ${_emails.length}'),
            Text('Alarms Set: ${_emails.where((e) => e.hasAlarm).length}'),
            Text('Very Important: ${_emails.where((e) => e.isVeryImportant).length}', 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
              if (result == true) {
                // Profile was saved, reload and refresh emails
                _userProfile = await _profileService.loadProfile();
                _refreshEmails();
              }
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
          ),
          if (_client != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // Properly sign out from Google
                await _gmailService.signOut();
                
                // Clear saved state
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isSignedIn', false);
                
                setState(() {
                  _client = null;
                  _emails.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}


