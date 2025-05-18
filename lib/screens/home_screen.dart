import 'package:auth_app/interfaces/task_interface.dart';
import 'package:auth_app/providers/auth_provider.dart';
import 'package:auth_app/providers/kanban_provider.dart';
import 'package:auth_app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boardview/board_item.dart';
import 'package:flutter_boardview/board_list.dart';
import 'package:flutter_boardview/boardview.dart';
import 'package:flutter_boardview/boardview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BoardViewController _boardViewController = BoardViewController();

  @override
  void initState() {
    super.initState();
  }

  void _showTaskDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return TaskDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    
    final authState = ref.watch(authProvider);
    final boardState = ref.watch(boardProvider);

    final todoTasks =
        boardState.tasks.where((t) => t.status == TaskStatus.pending).toList();
    final inProgressTasks =
        boardState.tasks
            .where((t) => t.status == TaskStatus.inProgress)
            .toList();
    final doneTasks =
        boardState.tasks.where((t) => t.status == TaskStatus.done).toList();

    final pendingColors = {
      'header': Colors.orange.shade700,
      'bg': Colors.orange.shade50,
      'fg': Colors.orange.shade900,
    };
    final progressColors = {
      'header': Colors.blue.shade700,
      'bg': Colors.blue.shade50,
      'fg': Colors.blue.shade900,
    };
    final doneColors = {
      'header': Colors.green.shade700,
      'bg': Colors.green.shade50,
      'fg': Colors.green.shade900,
    };

    List<BoardList> allBoardLists = [
      _createBoardListForStatus(
        context,
        ref,
        TaskStatus.pending,
        todoTasks,
        pendingColors['header']!,
        pendingColors['bg']!,
      ),
      _createBoardListForStatus(
        context,
        ref,
        TaskStatus.inProgress,
        inProgressTasks,
        progressColors['header']!,
        progressColors['bg']!,
      ),
      _createBoardListForStatus(
        context,
        ref,
        TaskStatus.done,
        doneTasks,
        doneColors['header']!,
        doneColors['bg']!,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kanban de ${authState.user?.userMetadata?['name']?.toString() ?? 'Usuario'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          if (boardState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          IconButton(
            onPressed: () => _showTaskDialog(),
            icon: const Icon(Icons.add_task_outlined),
            tooltip: 'Nueva Tarea',
          ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Cerrar Sesión'),
                      content: const Text(
                        '¿Estás seguro de que quieres cerrar sesión?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sí, Cerrar Sesión'),
                        ),
                      ],
                    ),
              );
              if (confirmed == true && mounted) {
                await ref.read(authProvider.notifier).logout();
                context.go('/');
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          top: 8.0,
          left: 4.0,
          right: 4.0,
          bottom: 8.0,
        ),
        child: BoardView(
          lists: allBoardLists,
          boardViewController: _boardViewController,
          dragDelay: 150,
          width:
              MediaQuery.of(context).size.width * 0.33 < 320
                  ? 300
                  : MediaQuery.of(context).size.width * 0.33,
        ),
      ),
    );
  }

  BoardList _createBoardListForStatus(
    BuildContext context,
    WidgetRef ref,
    TaskStatus status,
    List<Task> tasks,
    Color headerColor,
    Color cardBgColor,
  ) {
    List<BoardItem> items =
        tasks.map((task) {
          return BoardItem(
            draggable: true,
            onDropItem: (
              oldListIndex,
              oldItemIndex,
              newListIndex,
              newItemIndex,
              state,
            ) {
              ref
                  .read(boardProvider.notifier)
                  .updateTaskStatus(task.id, TaskStatus.values[oldListIndex!]);
            },
            item: TaskCard(
              task: task,
              backgroundColor: cardBgColor,
              onTap: () => context.push('/task-detail', extra: task),
              // onTap: () => _showTaskDialog(taskToEdit: task),
              onDelete: () async {
                final boardState = ref.watch(boardProvider);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (dialogContext) => AlertDialog(
                        title: const Text('Confirmar Eliminación'),
                        content: Text(
                          '¿Estás seguro de que quieres eliminar la tarea "${task.title}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed:
                                () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(dialogContext).pop(true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  await ref.read(boardProvider.notifier).deleteTask(task.id);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          boardState.errorMessage == null
                              ? 'Tarea "${task.title}" eliminada.'
                              : boardState.errorMessage!,
                        ),
                        backgroundColor:
                            boardState.errorMessage == null
                                ? Colors.green
                                : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
            ),
          );
        }).toList();
    return BoardList(
      header: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
          child: Text(
            ref.read(boardProvider.notifier).getNameList(status),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: headerColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
      items: items,
      backgroundColor:
          status == TaskStatus.done
              ? Colors.green.shade100
              : status == TaskStatus.inProgress
              ? Colors.blue.shade100
              : Colors.orange.shade100,
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Text(
          "${tasks.length} tarea(s)",
          style: TextStyle(
            fontSize: 11,
            color:
                status == TaskStatus.done
                    ? Colors.green.shade900
                    : status == TaskStatus.inProgress
                    ? Colors.blue.shade900
                    : Colors.orange.shade900,
          ),
        ),
      ),
    );
  }
}
