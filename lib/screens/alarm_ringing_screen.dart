import 'package:flutter/material.dart';
import 'package:bell/services/in_app_alarm_service.dart';
import 'package:intl/intl.dart';
import '../widgets/success_alert_bar.dart';

class AlarmRingingScreen extends StatefulWidget {
  final String emailId;
  final String subject;
  final String sender;
  final DateTime alarmTime;

  const AlarmRingingScreen({
    Key? key,
    required this.emailId,
    required this.subject,
    required this.sender,
    required this.alarmTime,
  }) : super(key: key);

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismissAlarm() async {
    await InAppAlarmService.stopAlarm();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _snooze() async {
    await InAppAlarmService.stopAlarm();
    // Snooze for 10 minutes
    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
    await InAppAlarmService().scheduleAlarm(
      emailId: widget.emailId,
      subject: widget.subject,
      sender: widget.sender,
      scheduledTime: snoozeTime,
    );
    
    if (mounted) {
      showSuccessAlert(
        context,
        '⏰ Alarm snoozed for 10 minutes',
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Time display
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(widget.alarmTime),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, MMMM d').format(widget.alarmTime),
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Animated bell icon
            Expanded(
              flex: 3,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 0.5 - 0.25,
                      child: Icon(
                        Icons.notifications_active,
                        size: 120,
                        color: Color.lerp(
                          const Color(0xFFFFC107),
                          Colors.orange,
                          _animationController.value,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Email details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subject,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'From: ${widget.sender}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // Snooze button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _snooze,
                      icon: const Icon(Icons.snooze, color: Colors.white),
                      label: const Text(
                        'Snooze\n10 min',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: const BorderSide(color: Colors.white70, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Dismiss button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _dismissAlarm,
                      icon: const Icon(Icons.check, color: Colors.black),
                      label: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
