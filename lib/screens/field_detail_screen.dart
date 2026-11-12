import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'crops_screen.dart';
import 'field_form_screen.dart';
import 'fields_screen.dart';
import 'harvest_screen.dart';
import 'planting_form_screen.dart';
import 'task_form_screen.dart';

class FieldDetailScreen extends StatelessWidget {
  const FieldDetailScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final field = state.fieldById(fieldId);
    if (field == null) {
      return const Scaffold(body: EmptyState(icon: Icons.landscape_outlined, title: 'Поле удалено'));
    }
    final planting = state.activePlantingFor(field.id);
    final tasks = state.tasks.where((t) => t.fieldId == field.id).toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        // Невыполненные — от ближайших, выполненные — сначала последние.
        return a.done ? b.date.compareTo(a.date) : a.date.compareTo(b.date);
      });
    final totalTasks = tasks.length;
    const doneLimit = 10;
    final hiddenDone = max(0, tasks.where((t) => t.done).length - doneLimit);
    if (hiddenDone > 0) tasks.removeRange(tasks.length - hiddenDone, tasks.length);
    final harvests = state.harvestsSorted.where((h) => h.fieldId == field.id).toList();
    final fieldFin = state.finances.where((e) => e.fieldId == field.id);
    final income = state.incomeOf(fieldFin);
    final expense = state.expenseOf(fieldFin);

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(
        title: Text(field.name),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => open(FieldFormScreen(field: field)),
          ),
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDelete(
                context,
                title: 'Удалить «${field.name}»?',
                message: 'Будут удалены посадки, работы и записи урожая этого поля. '
                    'Финансовые записи сохранятся.',
              );
              if (ok && context.mounted) {
                Navigator.pop(context);
                state.deleteField(field.id);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _info(Icons.square_foot, 'Площадь', fmtHa(field.areaHa)),
                    _info(Icons.terrain, 'Почва', field.soil.label),
                    if (field.location.isNotEmpty) _info(Icons.place_outlined, 'Место', field.location),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Статус: '),
                        PopupMenuButton<FieldStatus>(
                          tooltip: 'Изменить статус',
                          initialValue: field.status,
                          onSelected: (s) {
                            field.status = s;
                            state.saveField(field);
                          },
                          itemBuilder: (_) => [
                            for (final s in FieldStatus.values) PopupMenuItem(value: s, child: Text(s.label)),
                          ],
                          child: Row(children: [StatusChip(status: field.status), const Icon(Icons.arrow_drop_down)]),
                        ),
                      ],
                    ),
                    if (field.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(field.notes, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Культура'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: planting == null
                ? Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.grass),
                      title: const Text('Сейчас ничего не посажено'),
                      trailing: FilledButton.tonal(
                        onPressed: () => open(PlantingFormScreen(fieldId: field.id)),
                        child: const Text('Посадить'),
                      ),
                    ),
                  )
                : PlantingCard(planting: planting, showField: false),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_task),
                  label: const Text('Работа'),
                  onPressed: () => open(TaskFormScreen(fieldId: field.id)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.agriculture),
                  label: const Text('Урожай'),
                  onPressed: () => open(HarvestFormScreen(fieldId: field.id)),
                ),
              ],
            ),
          ),
          if (income > 0 || expense > 0) ...[
            const SectionHeader('Финансы по полю'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _info(Icons.arrow_downward, 'Доходы', fmtMoney(income), Colors.green),
                      _info(Icons.arrow_upward, 'Расходы', fmtMoney(expense), Colors.red),
                      const Divider(),
                      _info(Icons.calculate_outlined, 'Прибыль', fmtMoney(income - expense)),
                      if (field.areaHa > 0)
                        _info(Icons.straighten, 'Затраты на 1 га', fmtMoney(expense / field.areaHa)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SectionHeader('Работы ($totalTasks)'),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Работ по этому полю нет'),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (final t in tasks) TaskTile(task: t, showField: false),
                if (hiddenDone > 0)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text('И ещё $hiddenDone выполненных работ — смотрите в календаре'),
                  ),
              ]),
            ),
          SectionHeader('История урожая (${harvests.length})'),
          if (harvests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Урожай ещё не записан'),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [for (final h in harvests) HarvestTile(harvest: h, showField: false)]),
            ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value, [Color? color]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Text(label),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}
