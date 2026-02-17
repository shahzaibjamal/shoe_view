import 'package:hive/hive.dart';

part 'transaction_log.g.dart';

@HiveType(typeId: 0)
class TransactionLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String action; // CREATE, UPDATE, DELETE, BULK_DELETE, UPDATE_SETTINGS, SIGN_OUT, CLEAR_DATA

  @HiveField(3)
  final String entityId; // shipmentId_itemId or 'user_profile'

  @HiveField(4)
  final String entityName; // e.g., 'Jordan 4 Retro' or 'App Settings'

  @HiveField(5)
  final String summary; // Human-readable description

  @HiveField(6)
  final Map<String, dynamic>? metadata; // Optional raw data or changed field keys

  TransactionLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.entityId,
    required this.entityName,
    required this.summary,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'entityId': entityId,
      'entityName': entityName,
      'summary': summary,
      'metadata': metadata,
    };
  }
}
