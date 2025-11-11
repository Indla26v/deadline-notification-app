import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';

class NotesDatabase {
  static final NotesDatabase instance = NotesDatabase._init();
  static Database? _database;

  NotesDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
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
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        category TEXT,
        is_pinned INTEGER DEFAULT 0,
        is_secure INTEGER DEFAULT 0
      )
    ''');

    // Create index for faster queries
    await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
    await db.execute('CREATE INDEX idx_notes_secure ON notes(is_secure)');
    await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at DESC)');
  }

  Future<String> insertNote(NoteModel note) async {
    final db = await database;
    await db.insert('notes', note.toMap());
    return note.id;
  }

  Future<List<NoteModel>> getAllNotes({bool? isSecure}) async {
    final db = await database;
    
    String where = '';
    List<dynamic> whereArgs = [];
    
    if (isSecure != null) {
      where = 'is_secure = ?';
      whereArgs = [isSecure ? 1 : 0];
    }
    
    final result = await db.query(
      'notes',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return result.map((map) => NoteModel.fromMap(map)).toList();
  }

  Future<NoteModel?> getNote(String id) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return NoteModel.fromMap(result.first);
  }

  Future<int> updateNote(NoteModel note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(String id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<NoteModel>> searchNotes(String query, {bool? isSecure}) async {
    final db = await database;
    
    String where = '(title LIKE ? OR content LIKE ?)';
    List<dynamic> whereArgs = ['%$query%', '%$query%'];
    
    if (isSecure != null) {
      where += ' AND is_secure = ?';
      whereArgs.add(isSecure ? 1 : 0);
    }
    
    final result = await db.query(
      'notes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return result.map((map) => NoteModel.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
