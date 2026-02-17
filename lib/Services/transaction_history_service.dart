import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'transaction_log.dart';

class TransactionHistoryService {
  static const String _boxName = 'transaction_logs';
  static final TransactionHistoryService _instance = TransactionHistoryService._internal();
  
  factory TransactionHistoryService() => _instance;
  
  TransactionHistoryService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(TransactionLogAdapter());
    }
    await Hive.openBox<TransactionLog>(_boxName);
    _isInitialized = true;
  }

  Box<TransactionLog> get _box => Hive.box<TransactionLog>(_boxName);

  Future<void> log({
    required String action,
    required String entityId,
    required String entityName,
    required String summary,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) await init();

    final txn = TransactionLog(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      action: action,
      entityId: entityId,
      entityName: entityName,
      summary: summary,
      metadata: metadata,
    );

    await _box.add(txn);
  }

  List<TransactionLog> getAll() {
    if (!_isInitialized) return [];
    final logs = _box.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
    return logs;
  }

  Future<void> clear() async {
    if (!_isInitialized) await init();
    await _box.clear();
  }

  String exportToJson() {
    final logs = getAll();
    final jsonList = logs.map((l) => l.toJson()).toList();
    return jsonEncode(jsonList);
  }
}
