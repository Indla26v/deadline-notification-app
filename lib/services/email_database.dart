import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/email_model.dart';

class EmailDatabase {
  static final EmailDatabase instance = EmailDatabase._init();
  static Database? _database;

  EmailDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('emails.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add isUnread column
      await db.execute('ALTER TABLE emails ADD COLUMN isUnread INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE emails (
        id $idType,
        sender $textType,
        subject $textType,
        snippet $textType,
        body $textType,
        link $textType,
        pageToken TEXT,
        receivedDate TEXT,
        attachmentsJson $textType,
        hasAlarm $boolType,
        alarmTimesJson $textType,
        isVeryImportant $boolType,
        isUnread $boolType,
        threadId TEXT,
        messageCount $intType,
        threadMessagesJson TEXT,
        cachedAt $textType
      )
    ''');

    // Create index for faster queries
    await db.execute('CREATE INDEX idx_receivedDate ON emails(receivedDate)');
    await db.execute('CREATE INDEX idx_isVeryImportant ON emails(isVeryImportant)');
    await db.execute('CREATE INDEX idx_hasAlarm ON emails(hasAlarm)');
  }

  Future<void> insertEmail(EmailModel email) async {
    final db = await database;
    
    await db.insert(
      'emails',
      _emailToMap(email),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertEmails(List<EmailModel> emails) async {
    final db = await database;
    final batch = db.batch();
    
    for (final email in emails) {
      batch.insert(
        'emails',
        _emailToMap(email),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<EmailModel>> getAllEmails({int? limit}) async {
    final db = await database;
    
    final result = await db.query(
      'emails',
      orderBy: 'receivedDate DESC',
      limit: limit,
    );
    
    return result.map((json) => _emailFromMap(json)).toList();
  }

  Future<List<EmailModel>> getRecentEmails(int count) async {
    return getAllEmails(limit: count);
  }

  Future<EmailModel?> getEmailById(String id) async {
    final db = await database;
    
    final maps = await db.query(
      'emails',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _emailFromMap(maps.first);
  }

  Future<void> updateEmail(EmailModel email) async {
    final db = await database;
    
    await db.update(
      'emails',
      _emailToMap(email),
      where: 'id = ?',
      whereArgs: [email.id],
    );
  }

  Future<void> deleteOldEmails(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    await db.delete(
      'emails',
      where: 'receivedDate < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
    
    print('Deleted emails older than $daysToKeep days (before ${cutoffDate.toString()})');
  }

  Future<int> getEmailCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM emails');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search emails across subject, body, sender and snippet.
  /// Performs a case-insensitive LIKE search and returns results ordered by receivedDate DESC.
  Future<List<EmailModel>> searchEmails(String query, {int? limit}) async {
    final db = await database;
    final like = '%${query.replaceAll("%", "\\%").replaceAll("_", "\\_").toLowerCase()}%';

    final result = await db.rawQuery('''
      SELECT * FROM emails
      WHERE lower(subject) LIKE ?
         OR lower(body) LIKE ?
         OR lower(sender) LIKE ?
         OR lower(snippet) LIKE ?
      ORDER BY receivedDate DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', [like, like, like, like]);

    return result.map((json) => _emailFromMap(json)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Helper methods to convert between EmailModel and Map
  Map<String, dynamic> _emailToMap(EmailModel email) {
    return {
      'id': email.id,
      'sender': email.sender,
      'subject': email.subject,
      'snippet': email.snippet,
      'body': email.body,
      'link': email.link,
      'pageToken': email.pageToken,
      'receivedDate': email.receivedDate?.toIso8601String(),
      'attachmentsJson': jsonEncode(email.attachments.map((a) => {
        'filename': a.filename,
        'mimeType': a.mimeType,
        'attachmentId': a.attachmentId,
        'sizeBytes': a.sizeBytes,
      }).toList()),
      'hasAlarm': email.hasAlarm ? 1 : 0,
      'alarmTimesJson': jsonEncode(email.alarmTimes.map((dt) => dt.toIso8601String()).toList()),
      'isVeryImportant': email.isVeryImportant ? 1 : 0,
      'isUnread': email.isUnread ? 1 : 0,
      'threadId': email.threadId,
      'messageCount': email.messageCount,
      'threadMessagesJson': email.threadMessages != null 
        ? jsonEncode(email.threadMessages!.map((msg) => {
            'id': msg.id,
            'sender': msg.sender,
            'subject': msg.subject,
            'snippet': msg.snippet,
            'body': msg.body,
            'link': msg.link,
            'receivedDate': msg.receivedDate?.toIso8601String(),
            'isUnread': msg.isUnread,
            'attachmentsJson': jsonEncode(msg.attachments.map((a) => {
              'filename': a.filename,
              'mimeType': a.mimeType,
              'attachmentId': a.attachmentId,
              'sizeBytes': a.sizeBytes,
            }).toList()),
          }).toList())
        : null,
      'cachedAt': DateTime.now().toIso8601String(),
    };
  }

  EmailModel _emailFromMap(Map<String, dynamic> map) {
    final attachmentsJson = jsonDecode(map['attachmentsJson'] as String) as List;
    final alarmTimesJson = jsonDecode(map['alarmTimesJson'] as String) as List;
    
    List<EmailModel>? threadMessages;
    if (map['threadMessagesJson'] != null) {
      final threadMsgsJson = jsonDecode(map['threadMessagesJson'] as String) as List;
      threadMessages = threadMsgsJson.map((msgMap) {
        final msgAttachmentsJson = jsonDecode(msgMap['attachmentsJson'] as String) as List;
        return EmailModel(
          id: msgMap['id'],
          sender: msgMap['sender'],
          subject: msgMap['subject'],
          snippet: msgMap['snippet'],
          body: msgMap['body'],
          link: msgMap['link'],
          receivedDate: msgMap['receivedDate'] != null 
            ? DateTime.parse(msgMap['receivedDate']) 
            : null,
          isUnread: msgMap['isUnread'] == true || msgMap['isUnread'] == 1,
          attachments: msgAttachmentsJson.map((a) => EmailAttachment(
            filename: a['filename'],
            mimeType: a['mimeType'],
            attachmentId: a['attachmentId'],
            sizeBytes: a['sizeBytes'],
          )).toList(),
        );
      }).toList();
    }
    
    return EmailModel(
      id: map['id'],
      sender: map['sender'],
      subject: map['subject'],
      snippet: map['snippet'],
      body: map['body'],
      link: map['link'],
      pageToken: map['pageToken'],
      receivedDate: map['receivedDate'] != null 
        ? DateTime.parse(map['receivedDate']) 
        : null,
      attachments: attachmentsJson.map((a) => EmailAttachment(
        filename: a['filename'],
        mimeType: a['mimeType'],
        attachmentId: a['attachmentId'],
        sizeBytes: a['sizeBytes'],
      )).toList(),
      hasAlarm: map['hasAlarm'] == 1,
      alarmTimes: alarmTimesJson.map((dt) => DateTime.parse(dt)).toList(),
      isVeryImportant: map['isVeryImportant'] == 1,
      isUnread: map['isUnread'] == 1,
      threadId: map['threadId'],
      messageCount: map['messageCount'],
      threadMessages: threadMessages,
    );
  }
}
