import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board_app/interfaces/offiline_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kanban_board_app/interfaces/task_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class KanbanState {
  final bool isLoading;
  final String? errorMessage;
  final List<Task> tasks;
  final bool isOnline;
  final List<PendingOperation> pendingOperations;

  KanbanState({
    this.isLoading = false,
    this.errorMessage,
    this.tasks = const [],
    this.isOnline = true,
    this.pendingOperations = const [],
  });

  KanbanState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Task>? tasks,
    bool? isOnline,
    List<PendingOperation>? pendingOperations,
  }) {
    return KanbanState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      tasks: tasks ?? this.tasks,
      isOnline: isOnline ?? this.isOnline,
      pendingOperations: pendingOperations ?? this.pendingOperations,
    );
  }
}

class BoardNotifier extends StateNotifier<KanbanState> {
  final SupabaseClient _supabase;
  final String _userId;
  late SharedPreferences _prefs;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  final Uuid _uuid = Uuid();

  // Claves para almacenamiento local
  static const String _tasksKey = 'offline_tasks';
  static const String _pendingOperationsKey = 'pending_operations';

  BoardNotifier(this._supabase, this._userId) : super(KanbanState()) {
    _initializeOfflineSupport();
  }

  Future<void> _initializeOfflineSupport() async {
    _prefs = await SharedPreferences.getInstance();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );

    final connectivityResults = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(connectivityResults);

    await _loadLocalData();

    if (state.isOnline) {
      await syncPendingOperations();
      await fetchTasks();
    }

    if (state.isOnline) {
      getTaskRealtime();
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (isOnline && !state.isOnline) {
      state = state.copyWith(isOnline: true);
      await syncPendingOperations();
      await fetchTasks();
      getTaskRealtime();
    } else {
      state = state.copyWith(isOnline: isOnline);
      if (!isOnline) {
        _supabase.channel('custom-all-channel').unsubscribe();
      }
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final tasksJson = _prefs.getString(_tasksKey);
      if (tasksJson != null) {
        final List<dynamic> tasksList = jsonDecode(tasksJson);
        final tasks = tasksList.map((task) => Task.fromJson(task)).toList();

        final pendingOpsJson = _prefs.getString(_pendingOperationsKey);
        List<PendingOperation> pendingOps = [];

        if (pendingOpsJson != null) {
          final List<dynamic> pendingOpsList = jsonDecode(pendingOpsJson);
          pendingOps =
              pendingOpsList
                  .map((op) => PendingOperation.fromJson(op))
                  .toList();
        }

        state = state.copyWith(
          tasks: tasks,
          pendingOperations: pendingOps,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error cargando datos locales: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<void> _saveLocalData() async {
    try {
      final tasksJson = jsonEncode(
        state.tasks.map((task) => task.toJson()).toList(),
      );
      await _prefs.setString(_tasksKey, tasksJson);

      final pendingOpsJson = jsonEncode(
        state.pendingOperations.map((op) => op.toJson()).toList(),
      );
      await _prefs.setString(_pendingOperationsKey, pendingOpsJson);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error guardando datos locales: ${e.toString()}',
      );
    }
  }

  getTaskRealtime() async {
    if (!state.isOnline) return;
    _supabase
        .channel('custom-all-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (PostgresChangePayload payload) {
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.update ||
                payload.eventType == PostgresChangeEvent.delete) {
              fetchTasks();
            }
          },
        )
        .subscribe();
  }

  Future<void> fetchTasks() async {
    if (!state.isOnline) {
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      final tasksFromDb =
          (response as List).map((data) => Task.fromJson(data)).toList();

      state = state.copyWith(
        tasks: tasksFromDb,
        isLoading: false,
        errorMessage: null,
      );

      await _saveLocalData();
    } on PostgrestException catch (e) {
      state = state.copyWith(errorMessage: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error obteniendo tareas: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  Future<Map<String, dynamic>> addTask(
    String title,
    String? description,
  ) async {
    state = state.copyWith(isLoading: true);

    final String tempId = _uuid.v4();
    final DateTime now = DateTime.now();

    final newTask = Task(
      id: tempId,
      title: title,
      description: description ?? '',
      status: TaskStatus.pending,
      userId: _userId,
      createdAt: now,
      updatedAt: now,
    );

    final updatedTasks = [...state.tasks, newTask];

    if (state.isOnline) {
      try {
        final taskData = {
          "title": title,
          "description": description ?? '',
          "status": TaskStatus.pending.name,
          "user_id": _userId,
        };

        final response =
            await _supabase.from('tasks').insert(taskData).select();

        final serverTask = Task.fromJson(response[0]);
        final finalTasks =
            updatedTasks.map((t) => t.id == tempId ? serverTask : t).toList();

        state = state.copyWith(
          tasks: finalTasks,
          isLoading: false,
          errorMessage: null,
        );
        await _saveLocalData();
        return {"status": true, "message": "Tarea guardada con éxito"};
      } catch (e) {
        _addPendingOperation(PendingOperationType.add, {
          'tempId': tempId,
          'title': title,
          'description': description ?? '',
        });

        state = state.copyWith(
          tasks: updatedTasks,
          isLoading: false,
          errorMessage:
              'Tarea guardada localmente. Se sincronizará cuando haya conexión.',
        );
        await _saveLocalData();
        return {
          "status": true,
          "message":
              "Tarea guardada localmente. Se sincronizará cuando haya conexión.",
        };
      }
    } else {
      _addPendingOperation(PendingOperationType.add, {
        'tempId': tempId,
        'title': title,
        'description': description ?? '',
      });

      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        errorMessage:
            'Tarea guardada localmente. Se sincronizará cuando haya conexión.',
      );
      await _saveLocalData();
      return {
        "status": true,
        "message":
            "Tarea guardada localmente. Se sincronizará cuando haya conexión.",
      };
    }
  }

  Future<Map<String, dynamic>> updateTask(Task taskToUpdate) async {
    state = state.copyWith(isLoading: true);

    final taskUpdate = taskToUpdate.copyWith(updatedAt: DateTime.now());
    final tasksList =
        state.tasks
            .map((task) => task.id == taskUpdate.id ? taskUpdate : task)
            .toList();

    if (state.isOnline) {
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

        state = state.copyWith(
          tasks: tasksList,
          isLoading: false,
          errorMessage: null,
        );
        await _saveLocalData();
        return {"status": true, "message": "Tarea actualizada con éxito"};
      } catch (e) {
        _addPendingOperation(PendingOperationType.update, {
          'id': taskToUpdate.id,
          'title': taskToUpdate.title,
          'description': taskToUpdate.description,
          'status': taskToUpdate.status.name,
        });
        state = state.copyWith(
          tasks: tasksList,
          isLoading: false,
          errorMessage:
              'Tarea actualizada localmente. Se sincronizará cuando haya conexión.',
        );
        await _saveLocalData();
        return {
          "status": true,
          "message":
              "Tarea actualizada localmente. Se sincronizará cuando haya conexión.",
        };
      }
    } else {
      _addPendingOperation(PendingOperationType.update, {
        'id': taskToUpdate.id,
        'title': taskToUpdate.title,
        'description': taskToUpdate.description,
        'status': taskToUpdate.status.name,
      });

      state = state.copyWith(
        tasks: tasksList,
        isLoading: false,
        errorMessage:
            'Tarea actualizada localmente. Se sincronizará cuando haya conexión.',
      );
      await _saveLocalData();
      return {
        "status": true,
        "message":
            "Tarea actualizada localmente. Se sincronizará cuando haya conexión.",
      };
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

    final newTasks = List<Task>.from(state.tasks);
    newTasks[taskIndex] = updatedTask;

    if (state.isOnline) {
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
      } catch (e) {
        _addPendingOperation(PendingOperationType.updateStatus, {
          'id': taskId,
          'status': newStatus.name,
        });

        state = state.copyWith(
          tasks: newTasks,
          isLoading: false,
          errorMessage:
              'Estado actualizado localmente. Se sincronizará cuando haya conexión.',
        );
      }
    } else {
      _addPendingOperation(PendingOperationType.updateStatus, {
        'id': taskId,
        'status': newStatus.name,
      });

      state = state.copyWith(
        tasks: newTasks,
        isLoading: false,
        errorMessage:
            'Estado actualizado localmente. Se sincronizará cuando haya conexión.',
      );
    }

    await _saveLocalData();
  }

  Future<void> deleteTask(String taskId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final tasks = state.tasks.where((t) => t.id != taskId).toList();

    if (state.isOnline) {
      try {
        await _supabase.from('tasks').delete().eq('id', taskId);

        state = state.copyWith(tasks: tasks, isLoading: false);
      } catch (e) {
        _addPendingOperation(PendingOperationType.delete, {'id': taskId});

        state = state.copyWith(
          tasks: tasks,
          isLoading: false,
          errorMessage:
              'Tarea eliminada localmente. Se sincronizará cuando haya conexión.',
        );
      }
    } else {
      _addPendingOperation(PendingOperationType.delete, {'id': taskId});

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        errorMessage:
            'Tarea eliminada localmente. Se sincronizará cuando haya conexión.',
      );
    }

    await _saveLocalData();
  }

  void _addPendingOperation(
    PendingOperationType type,
    Map<String, dynamic> data,
  ) {
    final operation = PendingOperation(
      id: _uuid.v4(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );

    final newPendingOps = [...state.pendingOperations, operation];
    state = state.copyWith(pendingOperations: newPendingOps);
  }

  Future<void> syncPendingOperations() async {
    if (!state.isOnline || state.pendingOperations.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true);

    final sortedOps = List<PendingOperation>.from(state.pendingOperations)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    List<String> processedOpIds = [];
    Map<String, String> tempToRealIds = {};

    for (final operation in sortedOps) {
      try {
        switch (operation.type) {
          case PendingOperationType.add:
            final title = operation.data['title'] as String;
            final description = operation.data['description'] as String;
            final tempId = operation.data['tempId'] as String;

            final taskData = {
              "title": title,
              "description": description,
              "status": TaskStatus.pending.name,
              "user_id": _userId,
            };

            final response =
                await _supabase.from('tasks').insert(taskData).select();
            final serverTask = Task.fromJson(response[0]);

            tempToRealIds[tempId] = serverTask.id;
            processedOpIds.add(operation.id);
            break;

          case PendingOperationType.update:
            String taskId = operation.data['id'] as String;

            if (tempToRealIds.containsKey(taskId)) {
              taskId = tempToRealIds[taskId]!;
            }

            await _supabase
                .from('tasks')
                .update({
                  'title': operation.data['title'],
                  'description': operation.data['description'],
                  'status': operation.data['status'],
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', taskId);

            processedOpIds.add(operation.id);
            break;

          case PendingOperationType.updateStatus:
            String taskId = operation.data['id'] as String;

            if (tempToRealIds.containsKey(taskId)) {
              taskId = tempToRealIds[taskId]!;
            }

            await _supabase
                .from('tasks')
                .update({
                  'status': operation.data['status'],
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', taskId);

            processedOpIds.add(operation.id);
            break;

          case PendingOperationType.delete:
            String taskId = operation.data['id'] as String;

            if (tempToRealIds.containsKey(taskId)) {
              taskId = tempToRealIds[taskId]!;
            }

            await _supabase.from('tasks').delete().eq('id', taskId);
            processedOpIds.add(operation.id);
            break;
        }
      } catch (e) {
        continue;
      }
    }

    final remainingOps =
        state.pendingOperations
            .where((op) => !processedOpIds.contains(op.id))
            .toList();

    state = state.copyWith(pendingOperations: remainingOps, isLoading: false);

    await _saveLocalData();
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

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _supabase.channel('custom-all-channel').unsubscribe();
    super.dispose();
  }
}

final boardProvider =
    StateNotifierProvider.autoDispose<BoardNotifier, KanbanState>((ref) {
      final supabaseClient = Supabase.instance.client;
      final userId = supabaseClient.auth.currentUser?.id;
      return BoardNotifier(supabaseClient, userId!);
    });
