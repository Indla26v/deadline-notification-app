import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/calendar_event.dart';

class CalendarDatabase {
  static final CalendarDatabase instance = CalendarDatabase._init();
  static Database? _database;

  CalendarDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('calendar.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        color INTEGER NOT NULL,
        has_notification INTEGER DEFAULT 0,
        email_id TEXT
      )
    ''');

    // Create index for faster date queries
    await db.execute('CREATE INDEX idx_events_start ON events(start_time)');
    await db.execute('CREATE INDEX idx_events_email ON events(email_id)');
  }

  Future<String> insertEvent(CalendarEvent event) async {
    final db = await database;
    await db.insert('events', event.toMap());
    return event.id;
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    final db = await database;
    final result = await db.query(
      'events',
      orderBy: 'start_time ASC',
    );

    return result.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final db = await database;
    
    // Get start and end of day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final result = await db.query(
      'events',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time ASC',
    );

    return result.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<List<CalendarEvent>> getEventsForMonth(DateTime month) async {
    final db = await database;
    
    // Get start and end of month
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    final result = await db.query(
      'events',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time ASC',
    );

    return result.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<CalendarEvent?> getEvent(String id) async {
    final db = await database;
    final result = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return CalendarEvent.fromMap(result.first);
  }

  Future<int> updateEvent(CalendarEvent event) async {
    final db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(String id) async {
    final db = await database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CalendarEvent>> getEventsLinkedToEmail(String emailId) async {
    final db = await database;
    final result = await db.query(
      'events',
      where: 'email_id = ?',
      whereArgs: [emailId],
      orderBy: 'start_time ASC',
    );

    return result.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
