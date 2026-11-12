import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'task_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = dayOnly(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayTasks = state.tasksOn(_selected);

    // Типы работ по дням текущего месяца — для цветных точек.
    final marks = <int, List<TaskType>>{};
    for (final t in state.tasks) {
      if (t.date.year == _month.year && t.date.month == _month.month) {
        (marks[t.date.day] ??= []).add(t.type);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь работ'),
        actions: [IconButton(tooltip: 'Сегодня', icon: const Icon(Icons.today), onPressed: _goToday)],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Добавить работу',
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskFormScreen(date: _selected)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
              Expanded(
                child: Text(fmtMonthYear(_month),
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftMonth(1)),
            ],
          ),
          _MonthGrid(
            month: _month,
            selected: _selected,
            marks: marks,
            onSelect: (d) => setState(() => _selected = d),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final t in TaskType.values)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 4, backgroundColor: t.color),
                    const SizedBox(width: 4),
                    Text(t.label, style: const TextStyle(fontSize: 12)),
                  ]),
              ],
            ),
          ),
          SectionHeader(fmtWeekday(_selected)),
          if (dayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('На этот день работ нет. Нажмите +, чтобы добавить.'),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [for (final t in dayTasks) TaskTile(task: t, showDate: false)]),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.marks, required this.onSelect});
  final DateTime month;
  final DateTime selected;
  final Map<int, List<TaskType>> marks;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday - 1; // неделя начинается с понедельника
    final today = dayOnly(DateTime.now());
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(context, r * 7 + c - leading + 1, daysInMonth, today)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int day, int daysInMonth, DateTime today) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 48);
    final cs = Theme.of(context).colorScheme;
    final date = DateTime(month.year, month.month, day);
    final isSelected = sameDay(date, selected);
    final isToday = sameDay(date, today);
    final types = (marks[day] ?? []).toSet().take(3).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onSelect(date),
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : null,
          shape: BoxShape.circle,
          border: isToday && !isSelected ? Border.all(color: cs.primary, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                  color: isSelected ? cs.onPrimary : null,
                  fontWeight: isToday ? FontWeight.bold : null,
                )),
            if (types.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in types)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.onPrimary : t.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
