import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/subtask.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('todos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#2196F3',
        customColors TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        priority TEXT NOT NULL DEFAULT 'medium',
        dueDate INTEGER,
        categoryId INTEGER,
        isDone INTEGER NOT NULL DEFAULT 0,
        tags TEXT DEFAULT '',
        attachments TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        recurringConfig INTEGER DEFAULT 0,
        recurringInterval INTEGER DEFAULT 1,
        recurringDaysOfWeek TEXT DEFAULT '',
        recurringDayOfMonth INTEGER,
        recurringEndDate INTEGER,
        recurringHasEnd INTEGER DEFAULT 0,
        nextDueDate INTEGER,
        reminderAt INTEGER,
        hasReminder INTEGER DEFAULT 0,
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        isDone INTEGER NOT NULL DEFAULT 0,
        todoId INTEGER,
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (todoId) REFERENCES todos(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        todoId INTEGER,
        startedAt INTEGER NOT NULL,
        durationMinutes INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (todoId) REFERENCES todos(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE todos ADD COLUMN tags TEXT DEFAULT ""');
      await db.execute('ALTER TABLE todos ADD COLUMN attachments TEXT DEFAULT ""');
      await db.execute('ALTER TABLE categories ADD COLUMN customColors TEXT DEFAULT ""');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE todos ADD COLUMN recurringConfig INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE todos ADD COLUMN recurringInterval INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE todos ADD COLUMN recurringDaysOfWeek TEXT DEFAULT ""');
      await db.execute('ALTER TABLE todos ADD COLUMN recurringDayOfMonth INTEGER');
      await db.execute('ALTER TABLE todos ADD COLUMN recurringEndDate INTEGER');
      await db.execute('ALTER TABLE todos ADD COLUMN recurringHasEnd INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE todos ADD COLUMN nextDueDate INTEGER');
      await db.execute('ALTER TABLE todos ADD COLUMN reminderAt INTEGER');
      await db.execute('ALTER TABLE todos ADD COLUMN hasReminder INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE todos ADD COLUMN sortOrder INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE subtasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          isDone INTEGER NOT NULL DEFAULT 0,
          todoId INTEGER,
          sortOrder INTEGER DEFAULT 0,
          FOREIGN KEY (todoId) REFERENCES todos(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE pomodoro_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          todoId INTEGER,
          startedAt INTEGER NOT NULL,
          durationMinutes INTEGER NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (todoId) REFERENCES todos(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<int> insertTodo(Todo todo) async {
    final db = await database;
    return await db.insert('todos', todo.toMap());
  }

  Future<int> updateTodo(Todo todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Todo>> getAllTodos() async {
    final db = await database;
    final maps = await db.query('todos', orderBy: 'sortOrder ASC');
    final todos = <Todo>[];
    for (final map in maps) {
      final subtasks = await getSubtasksForTodo(map['id'] as int);
      todos.add(Todo.fromMap(map).copyWith(subtasks: subtasks));
    }
    return todos;
  }

  Future<List<Todo>> searchTodos(String query) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'title LIKE ? OR description LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return maps.map((map) => Todo.fromMap(map)).toList();
  }

  // Subtask operations
  Future<List<Subtask>> getSubtasksForTodo(int todoId) async {
    final db = await database;
    final maps = await db.query(
      'subtasks',
      where: 'todoId = ?',
      whereArgs: [todoId],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((map) => Subtask.fromMap(map)).toList();
  }

  Future<void> insertSubtask(Subtask subtask, int todoId) async {
    final db = await database;
    await db.insert('subtasks', subtask.toMap()..['todoId'] = todoId);
  }

  Future<void> updateSubtask(Subtask subtask) async {
    final db = await database;
    await db.update(
      'subtasks',
      subtask.toMap(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );
  }

  Future<void> deleteSubtask(String id) async {
    final db = await database;
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderSubtasks(List<Subtask> subtasks) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < subtasks.length; i++) {
      batch.update(
        'subtasks',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [subtasks[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // Pomodoro session operations
  Future<void> savePomodoroSession(int todoId, DateTime startedAt, int durationMinutes, bool completed) async {
    final db = await database;
    await db.insert('pomodoro_sessions', {
      'todoId': todoId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'completed': completed ? 1 : 0,
    });
  }

  Future<int> getPomodoroCount(int todoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pomodoro_sessions WHERE todoId = ? AND completed = 1',
      [todoId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPomodoroMinutes(int todoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(durationMinutes), 0) as total FROM pomodoro_sessions WHERE todoId = ? AND completed = 1',
      [todoId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertCategory(TodoCategory category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(TodoCategory category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.update(
      'todos',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TodoCategory>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'id ASC');
    return maps.map((map) => TodoCategory.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
