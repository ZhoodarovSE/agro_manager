import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/task_form_screen.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showDate = true, this.showField = true});
  final FarmTask task;
  final bool showDate;
  final bool showField;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final overdue = !task.done && task.date.isBefore(dayOnly(DateTime.now()));
    final parts = <String>[
      if (showDate) (overdue ? 'Просрочено · ${fmtShortDate(task.date)}' : fmtWeekday(task.date)),
      if (showField && task.fieldId != null) state.fieldName(task.fieldId),
      if (task.note.isNotEmpty) task.note,
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: task.type.color.withValues(alpha: 0.15),
        child: Icon(task.type.icon, color: task.type.color),
      ),
      title: Text(
        task.type.label,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? Theme.of(context).colorScheme.outline : null,
        ),
      ),
      subtitle: parts.isEmpty
          ? null
          : Text(
              parts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: overdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
            ),
      trailing: Checkbox(value: task.done, onChanged: (_) => state.toggleTask(task)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
      ),
    );
  }
}
