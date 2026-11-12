import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task, this.date, this.fieldId});
  final FarmTask? task;
  final DateTime? date;
  final String? fieldId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late TaskType _type = widget.task?.type ?? TaskType.watering;
  late DateTime _date = widget.task?.date ?? widget.date ?? dayOnly(DateTime.now());
  late String? _fieldId = widget.task?.fieldId ?? widget.fieldId;
  late final _note = TextEditingController(text: widget.task?.note);
  int _repeatWeeks = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<AppState>();
    final existing = widget.task;
    if (existing != null) {
      existing
        ..type = _type
        ..date = _date
        ..fieldId = _fieldId
        ..note = _note.text.trim();
      state.saveTask(existing);
    } else {
      // Повтор: например, полив раз в неделю на несколько недель вперёд.
      for (var i = 0; i <= _repeatWeeks; i++) {
        state.saveTask(FarmTask(
          id: newId(),
          type: _type,
          date: _date.add(Duration(days: 7 * i)),
          fieldId: _fieldId,
          note: _note.text.trim(),
        ));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fields = context.watch<AppState>().fields;
    final isEdit = widget.task != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Работа' : 'Новая работа'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDelete(context, title: 'Удалить работу?') && context.mounted) {
                  context.read<AppState>().deleteTask(widget.task!.id);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Вид работы', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in TaskType.values)
                ChoiceChip(
                  avatar: Icon(t.icon, size: 18, color: t.color),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DateField(label: 'Дата', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: fields.any((f) => f.id == _fieldId) ? _fieldId : null,
            decoration: const InputDecoration(labelText: 'Поле', prefixIcon: Icon(Icons.landscape_outlined)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Без привязки к полю')),
              for (final f in fields) DropdownMenuItem(value: f.id, child: Text(f.name)),
            ],
            onChanged: (v) => setState(() => _fieldId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Например: 100 кг селитры на гектар',
              alignLabelWithHint: true,
            ),
          ),
          if (!isEdit) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _repeatWeeks,
              decoration: const InputDecoration(labelText: 'Повторять', prefixIcon: Icon(Icons.repeat)),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Не повторять')),
                DropdownMenuItem(value: 1, child: Text('Каждую неделю, 2 раза')),
                DropdownMenuItem(value: 3, child: Text('Каждую неделю, 4 раза')),
                DropdownMenuItem(value: 7, child: Text('Каждую неделю, 8 раз')),
              ],
              onChanged: (v) => setState(() => _repeatWeeks = v ?? 0),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Сохранить')),
        ],
      ),
    );
  }
}
