class Task {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  Task copyWith({String? title, String? description}) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}

enum TaskStatus { pending, inProgress, done }
