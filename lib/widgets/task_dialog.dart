import 'package:auth_app/interfaces/task_interface.dart';
import 'package:flutter/material.dart';

class TaskDialog extends StatefulWidget {
  final Task? taskToEdit;
  final Function(
    String title,
    String? description,
    TaskStatus status,
    Task? originalTask,
  )
  onSave;

  const TaskDialog({super.key, this.taskToEdit, required this.onSave});

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TaskStatus _selectedStatus;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.taskToEdit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.taskToEdit?.description ?? '',
    );
    _selectedStatus = widget.taskToEdit?.status ?? TaskStatus.pending;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      widget.onSave(
        title,
        description.isNotEmpty ? description : null,
        _selectedStatus, // Pasar el estado seleccionado
        widget
            .taskToEdit, // Pasar la tarea original para referencia si se está editando
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Tarea' : 'Nueva Tarea'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Para evitar overflow si el teclado aparece
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
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
                // Usar TextFormField para consistencia
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Descripción detallada...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  // Opcional: guardar al presionar "done" en el teclado
                  if (isEditing) {
                    _handleSave(); // Solo para edición, para creación es mejor botón explícito
                  }
                },
              ),
              const SizedBox(height: 16),
              // Permitir cambiar el estado solo si se está editando
              // y si el estado actual NO es el que se está seleccionando (opcional)
              if (isEditing)
                DropdownButtonFormField<TaskStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      TaskStatus.values.map((TaskStatus status) {
                        return DropdownMenuItem<TaskStatus>(
                          value: status,
                          child: Text(status.name),
                        );
                      }).toList(),
                  onChanged: (TaskStatus? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStatus = newValue;
                      });
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: Text(isEditing ? 'Guardar Cambios' : 'Crear Tarea'),
        ),
      ],
    );
  }
}
