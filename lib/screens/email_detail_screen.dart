import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import '../models/email_model.dart';
import '../services/gmail_service.dart';
import '../services/email_database.dart';
import '../services/alarm_service.dart';
import '../services/in_app_alarm_service.dart';
import '../widgets/success_alert_bar.dart';
import '../widgets/parser_results_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

class EmailDetailScreen extends StatefulWidget {
  final EmailModel email;
  final auth.AuthClient? client;

  const EmailDetailScreen({
    Key? key,
    required this.email,
    this.client,
  }) : super(key: key);

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  final GmailService _gmailService = GmailService();
  final EmailDatabase _emailDatabase = EmailDatabase.instance;
  final AlarmService _alarmService = AlarmService();
  final InAppAlarmService _inAppAlarmService = InAppAlarmService();
  final Map<String, bool> _downloadingAttachments = {};
  String? _googleFormUrl;

  @override
  void initState() {
    super.initState();
    _detectGoogleForm();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    // Mark as read in local database
    if (widget.email.isUnread) {
      widget.email.isUnread = false;
      await _emailDatabase.updateEmail(widget.email);
      
      // Also mark as read in Gmail if client is available
      if (widget.client != null) {
        await _gmailService.markAsRead(widget.client!, widget.email.id);
      }
    }
  }

  void _detectGoogleForm() {
    // Check main email body
    final formUrlMatch = RegExp(r'https://docs\.google\.com/forms/[^\s<>"\)]+').firstMatch(widget.email.body);
    if (formUrlMatch != null) {
      _googleFormUrl = formUrlMatch.group(0);
      return;
    }

    // Check thread messages if available
    if (widget.email.threadMessages != null) {
      for (var message in widget.email.threadMessages!) {
        final threadFormMatch = RegExp(r'https://docs\.google\.com/forms/[^\s<>"\)]+').firstMatch(message.body);
        if (threadFormMatch != null) {
          _googleFormUrl = threadFormMatch.group(0);
          return;
        }
      }
    }
  }

  // Helper to build text with proper formatting
  Widget _buildEmailBody(String body) {
    // Check if body contains HTML tags
    final hasHtml = body.contains('<html') || 
                    body.contains('<body') || 
                    body.contains('<div') ||
                    body.contains('<p>') ||
                    body.contains('<br>') ||
                    body.contains('<table') ||
                    body.contains('</td>') ||
                    body.contains('<span');
    
    if (hasHtml) {
      // Render as HTML
      print('📧 Rendering HTML body (length: ${body.length} chars)');
      return Container(
        width: double.infinity,
        child: Html(
          data: body,
          shrinkWrap: false,
          style: {
            "*": Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            "body": Style(
              fontSize: FontSize(15),
              lineHeight: LineHeight(1.6),
              color: Colors.black87,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              display: Display.block,
            ),
            "html": Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              display: Display.block,
            ),
            "p": Style(
              margin: Margins.only(bottom: 8),
              display: Display.block,
            ),
          "a": Style(
            color: Colors.blue,
            textDecoration: TextDecoration.underline,
          ),
          "table": Style(
            border: Border.all(color: Colors.grey.shade300),
            backgroundColor: Colors.grey.shade50,
          ),
          "td": Style(
            padding: HtmlPaddings.all(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          "th": Style(
            padding: HtmlPaddings.all(8),
            backgroundColor: Colors.blue.shade100,
            fontWeight: FontWeight.bold,
            border: Border.all(color: Colors.grey.shade300),
          ),
          "div": Style(
            display: Display.block,
          ),
          "span": Style(
            display: Display.inline,
          ),
        },
        onLinkTap: (url, attributes, element) async {
          if (url != null) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        ),
      );
    }
    
    print('📧 Rendering plain text body (length: ${body.length} chars)');
    
    // Plain text rendering (existing logic)
    final lines = body.split('\n');
    final widgets = <Widget>[];
    bool inTable = false;
    List<String> tableLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Detect table/structured data (lines with IDs or "Candidate" headers)
      final isTableLine = RegExp(r'^\s*\d{7,}').hasMatch(line) ||
                         line.contains('Candidate Id') ||
                         line.contains('Primary Email') ||
                         line.contains('Reg. No.');
      
      if (isTableLine) {
        if (!inTable) {
          // Starting a table - add previous regular text if any
          inTable = true;
        }
        tableLines.add(line);
      } else {
        if (inTable && tableLines.isNotEmpty) {
          // End of table - add it as a highlighted section
          widgets.add(_buildTableSection(tableLines.join('\n')));
          tableLines = [];
          inTable = false;
        }
        
        // Add regular line
        if (line.trim().isNotEmpty) {
          // Check if line is a heading (starts with *, bold markers, or all caps short line)
          final isHeading = line.trim().startsWith('*') || 
                           line.trim().endsWith('*') ||
                           (line.trim().length < 50 && line.trim() == line.trim().toUpperCase());
          
          // Check if line is a note or important text
          final isNote = line.toLowerCase().contains('note:') || 
                        line.toLowerCase().contains('disclaimer:');
          
          widgets.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: isHeading || isNote ? 12.0 : 6.0,
                top: isHeading ? 8.0 : 0,
              ),
              child: Linkify(
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                text: line.replaceAll('*', ''),
                style: TextStyle(
                  fontSize: isHeading ? 17 : 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                  fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
                  color: isNote ? Colors.orange.shade900 : Colors.black87,
                ),
                linkStyle: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                ),
              ),
            ),
          );
        }
      }
    }
    
    // Add remaining table if exists
    if (tableLines.isNotEmpty) {
      widgets.add(_buildTableSection(tableLines.join('\n')));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildTableSection(String tableText) {
    // Parse table rows
    final lines = tableText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, size: 20, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Text(
                  'Selected Candidates (${lines.length > 1 ? lines.length - 1 : lines.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          
          // Table rows
          Container(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                final isHeader = index == 0 && (line.contains('S.No') || line.contains('Candidate'));
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: isHeader ? Colors.blue.shade700 : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHeader ? Colors.blue.shade800 : Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: SelectableText(
                    line,
                    style: TextStyle(
                      fontSize: isHeader ? 13 : 14,
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                      color: isHeader ? Colors.white : Colors.black87,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadMessage(EmailModel message, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false, // Keep all threads collapsed by default
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  message.subject.isEmpty ? '(No subject)' : message.subject,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (message.attachments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file, size: 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '${message.attachments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                message.sender,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.receivedDate != null)
                Text(
                  DateFormat('MMM d, h:mm a').format(message.receivedDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmailBody(message.body),
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Attachments (${message.attachments.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...message.attachments.map((attachment) => _buildAttachmentCard(attachment)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAlarm() async {
    try {
      final text = '${widget.email.subject}\n${widget.email.body}';
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('DETECTING TIME FROM EMAIL:');
      print('Subject: ${widget.email.subject}');
      print('Body preview: ${widget.email.body.substring(0, widget.email.body.length > 200 ? 200 : widget.email.body.length)}...');
      
      final parseResult = _alarmService.parseTimeFromText(text);
      
      print('Parse result: $parseResult');
      
      if (parseResult == null) {
        if (!mounted) return;
        showSuccessAlert(
          context,
          '⚠️ No valid time found in this email.',
        );
        return;
      }

      final detectedTime = parseResult['finalDate'] as DateTime?;
      final candidatesLog = parseResult['candidatesLog'] as List<String>;

      print('Detected time: $detectedTime');
      if (detectedTime != null) {
        final dateFormat = DateFormat('MMM d, yyyy HH:mm:ss');
        print('Formatted: ${dateFormat.format(detectedTime)}');
        print('Millis: ${detectedTime.millisecondsSinceEpoch}');
      }
      print('CANDIDATES LOG:\n${candidatesLog.join('\n')}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (detectedTime == null) {
        if (!mounted) return;
        showSuccessAlert(
          context,
          '⚠️ No valid time found in this email.',
        );
        return;
      }

      // Show parser results dialog
      if (!mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ParserResultsDialog(
          parseResult: parseResult,
          emailSubject: widget.email.subject,
          emailBody: widget.email.body.length > 500 
              ? '${widget.email.body.substring(0, 500)}...' 
              : widget.email.body,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      );

      if (confirmed != true || !mounted) return;

      // Check if the time is in the past
      if (detectedTime.isBefore(DateTime.now())) {
        if (!mounted) return;
        showSuccessAlert(
          context,
          '⚠️ Cannot set alarm for past time',
        );
        return;
      }

      // Schedule the in-app alarm
      await _inAppAlarmService.scheduleAlarm(
        emailId: widget.email.id,
        subject: widget.email.subject,
        sender: widget.email.sender,
        scheduledTime: detectedTime,
        emailLink: widget.email.link,
      );

      // Update email state
      setState(() {
        widget.email.hasAlarm = true;
        widget.email.alarmTimes = [detectedTime];
      });
      
      // Update in database
      await _emailDatabase.updateEmail(widget.email);

      if (!mounted) return;
      final dateFormat = DateFormat('MMM d, yyyy HH:mm:ss');
      final scheduledStr = dateFormat.format(detectedTime);
      showSuccessAlert(
        context,
        '✓ Alarm set for $scheduledStr',
      );
      
      // Notify parent to refresh
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(
        context,
        '❌ Error setting alarm',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _removeAlarm() async {
    try {
      // Save alarm time before removing for the snackbar message
      final removedTime = widget.email.alarmTimes.isNotEmpty 
          ? widget.email.alarmTimes.first 
          : null;
      
      // Cancel the in-app alarm
      await _inAppAlarmService.cancelAlarm(widget.email.id);
      
      setState(() {
        widget.email.hasAlarm = false;
        widget.email.alarmTimes = [];
      });
      
      // Update in database
      await _emailDatabase.updateEmail(widget.email);

      if (!mounted) return;
      final dateFormat = DateFormat('MMM d, h:mm a');
      final timeStr = removedTime != null 
          ? dateFormat.format(removedTime)
          : 'now';
      showSuccessAlert(
        context,
        '✓ Alarm removed for $timeStr',
      );
      
      // Notify parent to refresh
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(
        context,
        '❌ Error removing alarm',
      );
    }
  }

  Future<void> _addToImportant() async {
    try {
      // Add to SharedPreferences storage
      final prefs = await SharedPreferences.getInstance();
      final storedImportantIds = prefs.getStringList('veryImportantEmails') ?? [];
      if (!storedImportantIds.contains(widget.email.id)) {
        storedImportantIds.add(widget.email.id);
        await prefs.setStringList('veryImportantEmails', storedImportantIds);
      }
      
      setState(() {
        widget.email.isVeryImportant = true;
      });
      
      // Update in database
      await _emailDatabase.updateEmail(widget.email);

      if (!mounted) return;
      showSuccessAlert(
        context,
        '✓ Marked as Very Important',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(
        context,
        '❌ Error marking as important',
      );
    }
  }

  Future<void> _removeFromImportant() async {
    try {
      // Remove from SharedPreferences storage
      final prefs = await SharedPreferences.getInstance();
      final storedImportantIds = prefs.getStringList('veryImportantEmails') ?? [];
      storedImportantIds.remove(widget.email.id);
      await prefs.setStringList('veryImportantEmails', storedImportantIds);
      
      setState(() {
        widget.email.isVeryImportant = false;
      });
      
      // Update in database
      await _emailDatabase.updateEmail(widget.email);

      if (!mounted) return;
      showSuccessAlert(
        context,
        '✓ Removed from Very Important',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(
        context,
        '❌ Error removing from important',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Email Details'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'add_alarm':
                  await _addAlarm();
                  break;
                case 'remove_alarm':
                  await _removeAlarm();
                  break;
                case 'add_important':
                  await _addToImportant();
                  break;
                case 'remove_important':
                  await _removeFromImportant();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Alarm actions
              if (!widget.email.hasAlarm)
                const PopupMenuItem(
                  value: 'add_alarm',
                  child: Row(
                    children: [
                      Icon(Icons.alarm_add, size: 20, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Add Alarm'),
                    ],
                  ),
                ),
              if (widget.email.hasAlarm)
                const PopupMenuItem(
                  value: 'remove_alarm',
                  child: Row(
                    children: [
                      Icon(Icons.alarm_off, size: 20, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Remove Alarm'),
                    ],
                  ),
                ),
              // Very Important actions
              if (!widget.email.isVeryImportant)
                const PopupMenuItem(
                  value: 'add_important',
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Mark as Very Important'),
                    ],
                  ),
                ),
              if (widget.email.isVeryImportant)
                const PopupMenuItem(
                  value: 'remove_important',
                  child: Row(
                    children: [
                      Icon(Icons.star_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 12),
                      Text('Remove from Very Important'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: _googleFormUrl != null ? 100.0 : 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main email card with rounded corners
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject
                      Text(
                        widget.email.subject,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // From - with rounded background
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.shade700,
                              child: const Icon(Icons.person, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.email.sender,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Date - with icon
                      if (widget.email.receivedDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, yyyy at h:mm a').format(widget.email.receivedDate!),
                                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),
                      Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                      const SizedBox(height: 20),

                      // Email Body with automatic table detection and clickable links
                      _buildEmailBody(widget.email.body),
                    ],
                  ),
                ),

                // Thread Messages Section (if this is a conversation)
            if (widget.email.threadMessages != null && widget.email.threadMessages!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.forum, color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Thread (${widget.email.messageCount} messages)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sort by date (oldest first), then reverse to show latest first
              ...(widget.email.threadMessages!.toList()
                ..sort((a, b) {
                  if (a.receivedDate == null && b.receivedDate == null) return 0;
                  if (a.receivedDate == null) return -1;
                  if (b.receivedDate == null) return 1;
                  return a.receivedDate!.compareTo(b.receivedDate!);
                }))
                .reversed
                .toList()
                .asMap()
                .entries
                .map((entry) {
                final index = entry.key;
                final message = entry.value;
                return _buildThreadMessage(message, index);
              }),
            ],

            // Attachments Section - Only show if no thread messages (single email) or has unique attachments
            if (widget.email.attachments.isNotEmpty && 
                (widget.email.threadMessages == null || widget.email.threadMessages!.isEmpty)) ...[
              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 16),
              Text(
                'Attachments (${widget.email.attachments.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.email.attachments.map((attachment) => _buildAttachmentCard(attachment)),
            ],
          ],
        ),
      ),
          
          // Floating Google Form Button
          if (_googleFormUrl != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Material(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.blue.shade700,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      final uri = Uri.parse(_googleFormUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Open Google Form',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.description, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Form',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(EmailAttachment attachment) {
    final isDownloading = _downloadingAttachments[attachment.attachmentId] ?? false;
    final sizeStr = attachment.sizeBytes != null 
        ? _formatBytes(attachment.sizeBytes!) 
        : 'Unknown size';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDownloading ? null : () => _downloadAndOpenAttachment(attachment),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIconForMimeType(attachment.mimeType),
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.filename,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$sizeStr • ${attachment.mimeType}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isDownloading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.blue.shade700,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart;
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Icons.folder_zip;
    return Icons.attach_file;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _downloadAndOpenAttachment(EmailAttachment attachment) async {
    if (widget.client == null) {
      if (mounted) {
        showErrorAlert(
          context,
          '❌ Please sign in to download attachments',
        );
      }
      return;
    }

    setState(() {
      _downloadingAttachments[attachment.attachmentId] = true;
    });

    try {
      // Download attachment
      final attachmentData = await _gmailService.downloadAttachment(
        widget.client!,
        widget.email.id,
        attachment.attachmentId,
      );

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${attachment.filename}';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(attachmentData);

      // Open file
      final result = await OpenFile.open(filePath);
      
      if (result.type != ResultType.done) {
        if (mounted) {
          showErrorAlert(
            context,
            '❌ Could not open file',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorAlert(
          context,
          '❌ Error downloading attachment',
        );
      }
    } finally{
      setState(() {
        _downloadingAttachments[attachment.attachmentId] = false;
      });
    }
  }
}
