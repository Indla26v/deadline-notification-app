import 'package:flutter/material.dart';
import 'package:bell/services/in_app_alarm_service.dart';
import 'package:bell/services/email_database.dart';
import 'package:bell/widgets/glossy_snackbar.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AlarmManagementScreen extends StatefulWidget {
  const AlarmManagementScreen({Key? key}) : super(key: key);

  @override
  State<AlarmManagementScreen> createState() => _AlarmManagementScreenState();
}

class _AlarmManagementScreenState extends State<AlarmManagementScreen> {
  final InAppAlarmService _alarmService = InAppAlarmService();
  final EmailDatabase _emailDatabase = EmailDatabase.instance;
  List<Map<String, dynamic>> _alarms = [];
  bool _isLoading = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    // Update countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _alarms.isNotEmpty) {
        setState(() {
          // Just trigger rebuild to update countdowns
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    
    try {
      // The database is now synced automatically by InAppAlarmService.
      // We just need to get the latest list of alarms.
      final alarms = await _alarmService.getPendingAlarmsWithDetails();
      
      // Sort by scheduledTime (earliest first)
      alarms.sort((a, b) {
        final timeA = a['scheduledTime'] as DateTime;
        final timeB = b['scheduledTime'] as DateTime;
        return timeA.compareTo(timeB);
      });
      
      if (mounted) {
        setState(() {
          _alarms = alarms;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading alarms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelAlarm(String emailId, String subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Alarm'),
        content: Text('Are you sure you want to cancel the alarm for "$subject"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // The centralized InAppAlarmService now handles all database updates automatically.
      // We no longer need to manually update the database here.
      await _alarmService.cancelAlarm(emailId);
      
      showInfoSnackbar(context, 'Alarm cancelled');
      
      // Just reload the alarms from the service, which is the single source of truth.
      _loadAlarms();
      
      // Pop with 'true' to signal to the home page that a refresh might be needed.
      Navigator.pop(context, true);
    }
  }

  Future<void> _cancelAllAlarms() async {
    if (_alarms.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Alarms'),
        content: Text('Are you sure you want to cancel all ${_alarms.length} alarm(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // The centralized InAppAlarmService handles all database updates.
      // Loop through alarms and cancel them one by one. The service will handle the sync.
      for (final alarm in _alarms) {
        final emailId = alarm['emailId'] as String;
        await _alarmService.cancelAlarm(emailId);
      }
      
      showInfoSnackbar(context, 'All alarms cancelled');
      
      // Reload the list from the single source of truth.
      _loadAlarms();
      
      // Pop with 'true' to signal to the home page that a refresh is needed.
      Navigator.pop(context, true);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Always show exact date and time - no relative terms
    return DateFormat('MMM d, yyyy · h:mm a').format(dateTime);
  }

  String _getTimeRemaining(DateTime scheduledTime) {
    final now = DateTime.now();
    final difference = scheduledTime.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inSeconds <= 60 && difference.inSeconds > 0) {
      // Last minute - show seconds countdown
      return '${difference.inSeconds} sec';
    } else if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'in ${difference.inSeconds} second${difference.inSeconds == 1 ? '' : 's'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_alarms.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Cancel All Alarms',
              onPressed: _cancelAllAlarms,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAlarms,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? _buildEmptyState()
              : _buildAlarmList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.alarm_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Alarms',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set an alarm from any email to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    return ListView.builder(
      itemCount: _alarms.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final alarm = _alarms[index];
        final scheduledTime = alarm['scheduledTime'] as DateTime;
        final subject = alarm['subject'] as String;
        final sender = alarm['sender'] as String;
        final emailId = alarm['emailId'] as String;
        final isOverdue = scheduledTime.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOverdue ? Colors.red.shade200 : const Color(0xFFFFC107),
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isOverdue 
                    ? Colors.red.shade50 
                    : const Color(0xFFFFC107).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.alarm,
                color: isOverdue ? Colors.red : const Color(0xFFFFC107),
                size: 28,
              ),
            ),
            title: Text(
              subject,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'From: $sender',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(scheduledTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isOverdue ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue 
                        ? Colors.red.shade100
                        : (scheduledTime.difference(DateTime.now()).inSeconds <= 60 && scheduledTime.difference(DateTime.now()).inSeconds > 0)
                            ? Colors.red.shade100 // Red for last minute
                            : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTimeRemaining(scheduledTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue 
                          ? Colors.red.shade900
                          : (scheduledTime.difference(DateTime.now()).inSeconds <= 60 && scheduledTime.difference(DateTime.now()).inSeconds > 0)
                              ? Colors.red.shade900 // Red text for last minute
                              : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Cancel Alarm',
              onPressed: () => _cancelAlarm(emailId, subject),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
