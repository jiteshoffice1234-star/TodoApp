import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';

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
      version: 2,
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
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE todos ADD COLUMN tags TEXT DEFAULT ""');
      await db.execute('ALTER TABLE todos ADD COLUMN attachments TEXT DEFAULT ""');
      await db.execute('ALTER TABLE categories ADD COLUMN customColors TEXT DEFAULT ""');
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
    final maps = await db.query('todos');
    return maps.map((map) => Todo.fromMap(map)).toList();
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
