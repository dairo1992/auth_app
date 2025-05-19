enum TaskStatus { pending, inProgress, done }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String userId;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.status = TaskStatus.pending,
    this.createdAt,
    this.updatedAt,
    required this.userId,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    userId: userId ?? this.userId,
  );

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json["id"],
    title: json["title"],
    description: json["description"],
    status: TaskStatus.values.firstWhere((e) => e.name == json["status"]),
    createdAt:
    // json["createdAt"] != null
    DateTime.parse(json["created_at"]),
    // : DateTime.now(),
    updatedAt:
        json["updated_at"] != null ? DateTime.parse(json["updated_at"]) : null,
    userId: json["user_id"],
  );

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name, // Convertir el enum a String usando .name
      'user_id': userId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
