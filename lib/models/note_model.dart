class NoteModel {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  String? category;
  bool isPinned;
  bool isSecure; // For secure notes with biometric

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.isPinned = false,
    this.isSecure = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'category': category,
      'is_pinned': isPinned ? 1 : 0,
      'is_secure': isSecure ? 1 : 0,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      category: map['category'] as String?,
      isPinned: (map['is_pinned'] as int) == 1,
      isSecure: (map['is_secure'] as int) == 1,
    );
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    bool? isPinned,
    bool? isSecure,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isSecure: isSecure ?? this.isSecure,
    );
  }
}
