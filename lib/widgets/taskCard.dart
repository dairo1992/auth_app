import 'package:auth_app/interfaces/task_interface.dart';
import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color backgroundColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.backgroundColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  task.status == TaskStatus.pending
                      ? Icons.pending_actions_outlined
                      : task.status == TaskStatus.inProgress
                      ? Icons.incomplete_circle
                      : Icons.check_box_outlined,
                  size: 100,
                  color: Colors.black.withValues(alpha: 0.05),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.shade400,
                        ),
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Eliminar Tarea',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      task.description,
                      style: TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    task.createdAt != null
                        ? 'Creada: ${task.createdAt!.day}-${task.createdAt!.month}-${task.createdAt!.year} ${task.createdAt!.hour}:${task.createdAt!.minute}'
                        : "sin dato",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  task.updatedAt != null
                      ? Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Text(
                          'Actualizada: ${task.updatedAt!.day}-${task.updatedAt!.month}-${task.updatedAt!.year} ${task.updatedAt!.hour}:${task.updatedAt!.minute}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )
                      : Container(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
