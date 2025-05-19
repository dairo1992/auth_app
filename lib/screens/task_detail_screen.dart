import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_board_app/interfaces/task_interface.dart';
import 'package:kanban_board_app/providers/kanban_provider.dart';
import 'package:kanban_board_app/widgets/custom_button.dart';
import 'package:go_router/go_router.dart';
class TaskDetailScreen extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  late TaskStatus selectedStatus;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    selectedStatus = TaskStatus.pending;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        centerTitle: true,
        actions: [
          Text("Editar"),
          Switch.adaptive(
            value: _isEdit,
            onChanged: (value) {
              setState(() {
                _isEdit = !_isEdit;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 10),
                TextFormField(
                  readOnly: !_isEdit,
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Título de la tarea',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El título no puede estar vacío.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: !_isEdit,
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Descripción detallada...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskStatus>(
                  isExpanded: !_isEdit,
                  value: widget.task.status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      TaskStatus.values.map((TaskStatus status) {
                        return DropdownMenuItem<TaskStatus>(
                          value: status,
                          child: Text(
                            ref
                                .read(boardProvider.notifier)
                                .getNameList(status),
                          ),
                        );
                      }).toList(),
                  onChanged:
                      !_isEdit
                          ? null
                          : (TaskStatus? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedStatus = newValue;
                              });
                            }
                          },
                ),
                SizedBox(height: 15),
                _isEdit
                    ? CustomButton(
                      text: 'Actualizar',
 onPressed: () async {
                        await ref
                            .read(boardProvider.notifier)
                            .updateTask(
                              Task(
                                id: widget.task.id,
                                title: _titleController.text,
                                description: _descriptionController.text,
                                userId: widget.task.userId,
                                status: selectedStatus,
                              ),
                            );

                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                boardState.errorMessage == null
                                    ? "Tarea Actualizada"
                                    : boardState.errorMessage!,
                              ),
                              backgroundColor:
                                  boardState.errorMessage == null
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          );
                        context.pop();
                      },
                      isLoading: false,
                    )
                    : SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
