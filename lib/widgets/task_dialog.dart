import 'package:auth_app/providers/kanban_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TaskDialog extends ConsumerWidget {
  const TaskDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final boardState = ref.watch(boardProvider);
    return AlertDialog(
      title: Text('Nueva Tarea'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: titleController,
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
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (Opcional)',
                    hintText: 'Descripción detallada...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(boardProvider.notifier)
                .addTask(titleController.text, descriptionController.text);

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    boardState.errorMessage == null
                        ? "Tarea Registrada"
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
          child: Text('Crear Tarea'),
        ),
      ],
    );
  }
}
