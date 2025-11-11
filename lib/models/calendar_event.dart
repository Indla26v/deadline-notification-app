import 'package:flutter/material.dart';

class CalendarEvent {
  final String id;
  String title;
  String? description;
  DateTime startTime;
  DateTime? endTime;
  Color color;
  bool hasNotification;
  String? emailId; // Link to email if created from email alarm

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.color = Colors.blue,
    this.hasNotification = false,
    this.emailId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'color': color.value,
      'has_notification': hasNotification ? 1 : 0,
      'email_id': emailId,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      color: Color(map['color'] as int),
      hasNotification: (map['has_notification'] as int) == 1,
      emailId: map['email_id'] as String?,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    Color? color,
    bool? hasNotification,
    String? emailId,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      hasNotification: hasNotification ?? this.hasNotification,
      emailId: emailId ?? this.emailId,
    );
  }
}
