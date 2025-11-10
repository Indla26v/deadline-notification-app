import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:bell/services/alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlarmService.parseTimeFromText', () {
    final service = AlarmService();

    DateTime? parse(String s) => service.parseTimeFromText(s);

    test('parses "Nov 1, 12:00 PM" (no at)', () {
      final dt = parse('Meeting on Nov 1, 12:00 PM');
      expect(dt, isNotNull);
      // Year may roll over depending on current date; assert key components
      expect(dt!.month, 11);
      expect(dt.day, 1);
      expect(dt.hour, 12);
      expect(dt.minute, 0);
    });

    test('parses "31 Oct 2025 4.00 pm" (dot time, explicit year)', () {
      final dt = parse('Event: 31 Oct 2025 4.00 pm');
      expect(dt, isNotNull);
      expect(dt!.year, 2025);
      expect(dt.month, 10);
      expect(dt.day, 31);
      expect(dt.hour, 16);
      expect(dt.minute, 0);
    });

    test('parses "on 8th Nov by 8:30 am" (by preposition)', () {
      final dt = parse('Reminder on 8th Nov by 8:30 am');
      expect(dt, isNotNull);
      expect(dt!.month, 11);
      expect(dt.day, 8);
      expect(dt.hour, 8);
      expect(dt.minute, 30);
    });

    test('parses DATE/TIME block', () {
      final dt = parse('Subject: Test\nDATE: 14TH NOV\nTIME: 6:00 PM');
      expect(dt, isNotNull);
      // Month/day derive year based on today
      expect(dt!.month, 11);
      expect(dt.day, 14);
      expect(dt.hour, 18);
      expect(dt.minute, 0);
    });

    test('parses "November 8 at 8:30 am"', () {
      final dt = parse('Please join on November 8 at 8:30 am');
      expect(dt, isNotNull);
      expect(dt!.month, 11);
      expect(dt.day, 8);
      expect(dt.hour, 8);
      expect(dt.minute, 30);
    });
  });
}
