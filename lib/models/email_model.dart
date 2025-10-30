class EmailAttachment {
  final String filename;
  final String mimeType;
  final String attachmentId;
  final int? sizeBytes;

  EmailAttachment({
    required this.filename,
    required this.mimeType,
    required this.attachmentId,
    this.sizeBytes,
  });
}

class EmailModel {
  final String id;
  final String sender;
  final String subject;
  final String snippet;
  final String body;
  final String link;
  final String? pageToken;
  final DateTime? receivedDate;
  final List<EmailAttachment> attachments;
  bool hasAlarm;
  List<DateTime> alarmTimes; // List of scheduled alarm times
  bool isVeryImportant; // Flag for emails containing user's profile info
  bool isUnread; // Read/Unread status synced with Gmail
  
  // Threading support
  final String? threadId;
  final int messageCount; // Number of messages in thread
  final List<EmailModel>? threadMessages; // All messages in thread

  EmailModel({
    required this.id,
    required this.sender,
    required this.subject,
    required this.snippet,
    required this.body,
    required this.link,
    this.pageToken,
    this.receivedDate,
    this.attachments = const [],
    this.hasAlarm = false,
    this.alarmTimes = const [],
    this.isVeryImportant = false,
    this.isUnread = true,
    this.threadId,
    this.messageCount = 1,
    this.threadMessages,
  });
}


