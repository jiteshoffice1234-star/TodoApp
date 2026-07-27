import '../models/smart_list.dart';
import '../../core/database/database_helper.dart';

class SmartListRepository {
  final _db = DatabaseHelper.instance;

  Future<List<SmartList>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('smart_lists', orderBy: 'sortOrder ASC');
    return maps.map((m) => SmartList.fromMap(m)).toList();
  }

  Future<int> insert(SmartList sl) async {
    final db = await _db.database;
    return await db.insert('smart_lists', sl.toMap());
  }

  Future<void> update(SmartList sl) async {
    final db = await _db.database;
    await db.update('smart_lists', sl.toMap(), where: 'id = ?', whereArgs: [sl.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('smart_lists', where: 'id = ?', whereArgs: [id]);
  }
}
