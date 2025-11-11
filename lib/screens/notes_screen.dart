import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note_model.dart';
import '../services/notes_database.dart';
import '../services/secure_storage_service.dart';

class NotesScreen extends StatefulWidget {
  final bool isSecureVault;

  const NotesScreen({Key? key, this.isSecureVault = false}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NotesDatabase _notesDb = NotesDatabase.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<NoteModel> _notes = [];
  List<NoteModel> _filteredNotes = [];
  bool _loading = true;
  bool _isAuthenticated = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.isSecureVault) {
      _authenticateForSecureVault();
    } else {
      _loadNotes();
    }
  }

  Future<void> _authenticateForSecureVault() async {
    setState(() => _loading = true);
    
    // Check if should lock
    if (await _secureStorage.shouldLock()) {
      final authenticated = await _secureStorage.authenticate(
        reason: 'Authenticate to access secure notes',
      );
      
      if (!authenticated) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
        }
        return;
      }
    }
    
    await _secureStorage.updateLastAccessTime();
    setState(() => _isAuthenticated = true);
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    
    final notes = await _notesDb.getAllNotes(isSecure: widget.isSecureVault);
    
    // Load secure content if needed
    if (widget.isSecureVault) {
      for (var note in notes) {
        final secureContent = await _secureStorage.getSecureNote(note.id);
        if (secureContent != null) {
          note.content = secureContent;
        }
      }
    }
    
    setState(() {
      _notes = notes;
      _filteredNotes = notes;
      _loading = false;
    });
  }

  void _searchNotes(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredNotes = _notes;
      } else {
        _filteredNotes = _notes.where((note) {
          return note.title.toLowerCase().contains(query.toLowerCase()) ||
                 note.content.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isSecureVault ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.isSecureVault ? Icons.lock : Icons.note,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(widget.isSecureVault ? 'Secure Vault' : 'Notes'),
          ],
        ),
        backgroundColor: widget.isSecureVault ? Colors.grey[850] : Colors.blue.shade700,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                if (_notes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: widget.isSecureVault ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchNotes,
                      style: TextStyle(
                        color: widget.isSecureVault ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        hintStyle: TextStyle(
                          color: widget.isSecureVault ? Colors.grey[400] : Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search,
                          color: widget.isSecureVault ? Colors.grey[400] : Colors.grey[600],
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: widget.isSecureVault ? Colors.grey[400] : Colors.grey[600],
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchNotes('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                // Notes list
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.isSecureVault ? Icons.lock_open : Icons.note_add,
                                size: 64,
                                color: widget.isSecureVault ? Colors.grey[700] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No notes found'
                                    : widget.isSecureVault
                                        ? 'No secure notes yet'
                                        : 'No notes yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: widget.isSecureVault ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to create a new note',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.isSecureVault ? Colors.grey[600] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            return _buildNoteCard(note);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteEditor(),
        backgroundColor: widget.isSecureVault ? Colors.grey[800] : Colors.blue.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isSecureVault ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: note.isPinned
            ? Border.all(
                color: widget.isSecureVault ? Colors.amber.shade700 : Colors.amber,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isSecureVault ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => _showNoteEditor(note: note),
        title: Row(
          children: [
            if (note.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.push_pin,
                  size: 16,
                  color: widget.isSecureVault ? Colors.amber.shade700 : Colors.amber,
                ),
              ),
            Expanded(
              child: Text(
                note.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: widget.isSecureVault ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isSecureVault ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updated: ${DateFormat('MMM d, h:mm a').format(note.updatedAt)}',
              style: TextStyle(
                color: widget.isSecureVault ? Colors.grey[600] : Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(
            Icons.more_vert,
            color: widget.isSecureVault ? Colors.grey[400] : Colors.grey[700],
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pin',
              child: Row(
                children: [
                  Icon(
                    note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(note.isPinned ? 'Unpin' : 'Pin'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'pin') {
              _togglePin(note);
            } else if (value == 'delete') {
              _deleteNote(note);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showNoteEditor({NoteModel? note}) async {
    final isEditing = note != null;
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: widget.isSecureVault ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isSecureVault ? Colors.grey[850] : Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Note' : 'New Note',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a title')),
                        );
                        return;
                      }

                      if (isEditing) {
                        note.title = titleController.text.trim();
                        note.content = contentController.text.trim();
                        note.updatedAt = DateTime.now();
                        
                        if (widget.isSecureVault) {
                          await _secureStorage.storeSecureNote(note.id, note.content);
                          note.content = ''; // Clear content before storing in DB
                        }
                        
                        await _notesDb.updateNote(note);
                      } else {
                        final newNote = NoteModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          content: contentController.text.trim(),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          isSecure: widget.isSecureVault,
                        );
                        
                        if (widget.isSecureVault) {
                          await _secureStorage.storeSecureNote(newNote.id, newNote.content);
                          newNote.content = ''; // Clear content before storing in DB
                        }
                        
                        await _notesDb.insertNote(newNote);
                      }

                      await _loadNotes();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Note updated!' : 'Note created!'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: widget.isSecureVault ? Colors.grey[900] : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.isSecureVault ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Note title',
                        hintStyle: TextStyle(
                          color: widget.isSecureVault ? Colors.grey[600] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: TextField(
                        controller: contentController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.isSecureVault ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Start typing...',
                          hintStyle: TextStyle(
                            color: widget.isSecureVault ? Colors.grey[600] : Colors.grey[400],
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(NoteModel note) async {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    await _notesDb.updateNote(note);
    await _loadNotes();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(note.isPinned ? 'Note pinned' : 'Note unpinned'),
        ),
      );
    }
  }

  Future<void> _deleteNote(NoteModel note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.isSecureVault) {
        await _secureStorage.deleteSecureNote(note.id);
      }
      await _notesDb.deleteNote(note.id);
      await _loadNotes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
