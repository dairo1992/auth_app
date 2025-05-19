enum PendingOperationType { add, update, updateStatus, delete }

class PendingOperation {
  final String id;
  final PendingOperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: PendingOperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}