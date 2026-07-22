import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/models/subtask.dart';
import '../../data/models/recurring_config.dart';
import '../database/database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  Future<String> get _backupPath async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  Future<String> exportToJson(List<Todo> todos, List<TodoCategory> categories) async {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '3.0.0',
      'todos': todos.map((t) => t.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
    };
    
    final jsonStr = jsonEncode(data);
    final path = await _backupPath;
    final file = File('$path/todo_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<String> exportToCsv(List<Todo> todos, List<TodoCategory> categories) async {
    final rows = <List<dynamic>>[];
    rows.add([
      'ID', 'Title', 'Description', 'Priority', 'Due Date', 'Category', 
      'Done', 'Tags', 'Created', 'Updated', 'Recurring', 'Sort Order'
    ]);
    
    for (final todo in todos) {
      final catName = categories.where((c) => c.id == todo.categoryId).map((c) => c.name).firstOrNull ?? '';
      rows.add([
        todo.id,
        todo.title,
        todo.description,
        todo.priority,
        todo.dueDate?.toIso8601String() ?? '',
        catName,
        todo.isDone ? 'Yes' : 'No',
        todo.tags.join('; '),
        todo.createdAt.toIso8601String(),
        todo.updatedAt.toIso8601String(),
        todo.recurringConfig.label,
        todo.sortOrder,
      ]);
    }
    
    final csvStr = const ListToCsvConverter().convert(rows);
    final path = await _backupPath;
    final file = File('$path/todo_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvStr);
    return file.path;
  }

  Future<Map<String, dynamic>> importFromJson(String filePath) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    
    final todos = (data['todos'] as List).map((m) => Todo.fromMap(m as Map<String, dynamic>)).toList();
    final categories = (data['categories'] as List).map((m) => TodoCategory.fromMap(m as Map<String, dynamic>)).toList();
    
    return {
      'todos': todos,
      'categories': categories,
    };
  }

  Future<List<Todo>> importFromCsv(String filePath) async {
    final file = File(filePath);
    final csvStr = await file.readAsString();
    final rows = const CsvToListConverter().convert(csvStr);
    
    final todos = <Todo>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      todos.add(Todo(
        id: row[0] as int?,
        title: row[1].toString(),
        description: row[2].toString(),
        priority: row[3].toString(),
        dueDate: row[4].toString().isNotEmpty ? DateTime.tryParse(row[4].toString()) : null,
        isDone: row[6].toString() == 'Yes',
        tags: row[7].toString().split('; ').where((t) => t.isNotEmpty).toList(),
        createdAt: DateTime.tryParse(row[8].toString()) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(row[9].toString()) ?? DateTime.now(),
        sortOrder: row[11] is int ? row[11] as int : 0,
      ));
    }
    
    return todos;
  }

  Future<void> shareBackup(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], text: 'Todo App Backup'),
    );
  }

  Future<List<FileSystemEntity>> getBackupFiles() async {
    final path = await _backupPath;
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    return dir.listSync()..sort((a, b) => b.path.compareTo(a.path));
  }

  Future<void> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
