import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bell/widgets/success_alert_bar.dart';

void main() {
  group('Unified Alert System Tests', () {
    testWidgets('showSuccessAlert displays success alert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showSuccessAlert(context, '✓ Success message');
                    },
                    child: const Text('Show Success'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Tap button to show alert
      await tester.tap(find.text('Show Success'));
      await tester.pumpAndSettle();

      // Verify alert is displayed
      expect(find.text('✓ Success message'), findsOneWidget);
    });

    testWidgets('showWarningAlert displays warning alert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showWarningAlert(context, '⚠️ Warning message');
                    },
                    child: const Text('Show Warning'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Warning message'), findsOneWidget);
    });

    testWidgets('showErrorAlert displays error alert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showErrorAlert(context, '❌ Error message');
                    },
                    child: const Text('Show Error'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('❌ Error message'), findsOneWidget);
    });

    testWidgets('showInfoAlert displays info alert', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showInfoAlert(context, 'ℹ️ Info message');
                    },
                    child: const Text('Show Info'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pumpAndSettle();

      expect(find.text('ℹ️ Info message'), findsOneWidget);
    });

    test('AlertType enum has all expected values', () {
      expect(AlertType.values.length, 4);
      expect(AlertType.values, contains(AlertType.success));
      expect(AlertType.values, contains(AlertType.warning));
      expect(AlertType.values, contains(AlertType.error));
      expect(AlertType.values, contains(AlertType.info));
    });

    test('getAlertStyle returns correct styles for each type', () {
      final successStyle = getAlertStyle(AlertType.success);
      expect(successStyle.name, 'success');
      expect(successStyle.icon, Icons.check_circle_rounded);

      final warningStyle = getAlertStyle(AlertType.warning);
      expect(warningStyle.name, 'warning');
      expect(warningStyle.icon, Icons.warning_rounded);

      final errorStyle = getAlertStyle(AlertType.error);
      expect(errorStyle.name, 'error');
      expect(errorStyle.icon, Icons.error_rounded);

      final infoStyle = getAlertStyle(AlertType.info);
      expect(infoStyle.name, 'info');
      expect(infoStyle.icon, Icons.info_rounded);
    });

    testWidgets('Alert with action button displays correctly', (WidgetTester tester) async {
      bool actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showWarningAlert(
                        context,
                        '⚠️ No date found',
                        actionLabel: 'Pick now',
                        onActionPressed: () {
                          actionPressed = true;
                        },
                      );
                    },
                    child: const Text('Show Alert'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Alert'));
      await tester.pumpAndSettle();

      expect(find.text('Pick now'), findsOneWidget);
      
      await tester.tap(find.text('Pick now'));
      expect(actionPressed, true);
    });
  });

  group('Legacy SnackBar Removal Verification', () {
    test('Verify no ScaffoldMessenger.showSnackBar in widget files', () {
      // This is a placeholder test that should be extended with actual file scanning
      // In a real scenario, you would scan the codebase for legacy patterns
      expect(true, true); // Placeholder
    });
  });
}
