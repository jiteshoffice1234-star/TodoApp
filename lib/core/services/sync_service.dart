import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/todo.dart';
import '../../data/models/category.dart';
import '../../data/repositories/todo_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../database/database_helper.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final TodoRepository _todoRepo = TodoRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  StreamSubscription? _connectivitySub;
  bool _isOnline = true;

  Future<void> init() async {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      if (_isOnline) {
        syncToCloud();
      } else {
        _status = SyncStatus.offline;
      }
    });
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = !connectivity.contains(ConnectivityResult.none);
  }

  Future<SyncStatus> syncToCloud() async {
    if (!_isOnline) {
      _status = SyncStatus.offline;
      return _status;
    }

    _status = SyncStatus.syncing;

    try {
      final todos = await _todoRepo.getAll();
      final categories = await _categoryRepo.getAll();

      await _uploadTodos(todos);
      await _uploadCategories(categories);

      _status = SyncStatus.success;
    } catch (_) {
      _status = SyncStatus.error;
    }

    return _status;
  }

  Future<void> _uploadTodos(List<Todo> todos) async {
    // TODO: Implement Firebase Firestore upload
    // Requires Firebase project setup with google-services.json
    //
    // Example implementation:
    // final firestore = FirebaseFirestore.instance;
    // final batch = firestore.batch();
    // for (final todo in todos) {
    //   final ref = firestore.collection('todos').doc(todo.id.toString());
    //   batch.set(ref, {
    //     ...todo.toMap(),
    //     'userId': FirebaseAuth.instance.currentUser?.uid,
    //   });
    // }
    // await batch.commit();
  }

  Future<void> _uploadCategories(List<TodoCategory> categories) async {
    // TODO: Implement Firebase Firestore upload for categories
  }

  Future<List<Todo>> fetchFromCloud() async {
    // TODO: Implement Firestore fetch
    // Example:
    // final firestore = FirebaseFirestore.instance;
    // final snapshot = await firestore
    //     .collection('todos')
    //     .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
    //     .get();
    // return snapshot.docs.map((doc) => Todo.fromMap(doc.data())).toList();
    return [];
  }

  Future<void> signInAnonymously() async {
    // TODO: Implement Firebase anonymous auth
    // await FirebaseAuth.instance.signInAnonymously();
  }

  Future<void> signOut() async {
    // TODO: Implement Firebase sign out
    // await FirebaseAuth.instance.signOut();
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
