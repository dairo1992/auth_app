
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board_app/interfaces/task_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KanbanState {
  final bool isLoading;
  final String? errorMessage;
  final List<Task> tasks;

  KanbanState({
    this.isLoading = false,
    this.errorMessage,
    this.tasks = const [],
  });

  KanbanState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Task>? tasks,
  }) {
    return KanbanState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      tasks: tasks ?? this.tasks,
    );
  }
}

class BoardNotifier extends StateNotifier<KanbanState> {
  final SupabaseClient _supabase;
  final String _userId;

  BoardNotifier(this._supabase, this._userId) : super(KanbanState()) {
    fetchTasks();
  }

  getTaskRealtime() async {
    _supabase
        .channel('custom-all-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (PostgresChangePayload payload) {
            payload.eventType == PostgresChangeEvent.insert
                ? fetchTasks()
                : null;
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.channel('custom-all-channel').unsubscribe();
    super.dispose();
  }

  Future<void> fetchTasks() async {
    state = state.copyWith(isLoading: true, tasks: []);
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false); // O el orden que prefieras
      final tasksFromDb =
          (response as List).map((data) => Task.fromJson(data)).toList();

      state = state.copyWith(
        tasks: tasksFromDb,
        isLoading: false,
        errorMessage: null,
      );
    } on PostgrestException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    }
  }

  Future<void> addTask(String title, String? description) async {
    state = state.copyWith(isLoading: true);
    try {
      final newTask = {
        "title": title,
        "description": description!,
        "status": TaskStatus.pending.name,
        "user_id": _userId,
      };
      final response = await _supabase.from('tasks').insert(newTask).select();
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        tasks: [...state.tasks, Task.fromJson(response[0])],
      );
    } on PostgrestException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    }
  }

  Future<void> updateTask(Task taskToUpdate) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabase
          .from('tasks')
          .update({
            'title': taskToUpdate.title,
            'description': taskToUpdate.description,
            'status': taskToUpdate.status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskToUpdate.id);
      final taskUpdate = taskToUpdate.copyWith(updatedAt: DateTime.now());
      final tasksList =
          state.tasks.map((task) {
            if (task.id == taskUpdate.id) {
              return taskUpdate;
            }
            return task;
          }).toList();
      state = state.copyWith(
        tasks: tasksList,
        isLoading: false,
        errorMessage: null,
      );
    } on PostgrestException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    }
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    state = state.copyWith(isLoading: true);
    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final task = state.tasks[taskIndex];
    if (task.status == newStatus) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final updatedTask = task.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    final originalTasks = List<Task>.from(state.tasks);
    final newTasks = List<Task>.from(state.tasks);
    newTasks[taskIndex] = updatedTask;
    try {
      await _supabase
          .from('tasks')
          .update({
            'status': newStatus.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      state = state.copyWith(
        tasks: newTasks,
        isLoading: false,
        errorMessage: null,
      );
    } on PostgrestException catch (e) {
      state = state.copyWith(
        tasks: originalTasks,
        errorMessage: e.message,
        isLoading: false,
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
      final tasks = state.tasks.where((t) => t.id != taskId).toList();
      state = state.copyWith(tasks: tasks, isLoading: false);
    } on PostgrestException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    }
  }

  String getNameList(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Por Hacer';
      case TaskStatus.inProgress:
        return 'En Progreso';
      case TaskStatus.done:
        return 'Hecho';
    }
  }
}

final boardProvider =
    StateNotifierProvider.autoDispose<BoardNotifier, KanbanState>((ref) {
      final supabaseClient = Supabase.instance.client;
      final userId = supabaseClient.auth.currentUser?.id;
      return BoardNotifier(supabaseClient, userId!);
    });
