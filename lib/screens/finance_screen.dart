import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

enum _Period { month, year, all }

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  _Period _period = _Period.year;

  DateTime? get _from {
    final now = DateTime.now();
    return switch (_period) {
      _Period.month => DateTime(now.year, now.month),
      _Period.year => DateTime(now.year),
      _Period.all => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.financesSince(_from);
    final income = state.incomeOf(list);
    final expense = state.expenseOf(list);
    final profit = income - expense;

    final byCategory = <FinanceCategory, double>{};
    for (final e in list.where((e) => !e.isIncome)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Запись'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceFormScreen())),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.month, label: Text('Месяц')),
              ButtonSegment(value: _Period.year, label: Text('Год')),
              ButtonSegment(value: _Period.all, label: Text('Всё время')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: profit >= 0 ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Прибыль', style: Theme.of(context).textTheme.labelLarge),
                  Text(fmtMoney(profit),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          )),
                  if (income > 0)
                    Text('Рентабельность: ${(profit / income * 100).round()}%',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(icon: Icons.arrow_downward, label: 'Доходы', value: fmtMoney(income), color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(icon: Icons.arrow_upward, label: 'Расходы', value: fmtMoney(expense), color: Colors.red),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Структура расходов', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final c in categories)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(c.key.icon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.key.label)),
                        Text('${fmtMoney(c.value)} · ${(c.value / expense * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: c.value / expense, minHeight: 8),
                    ),
                  ],
                ),
              ),
          ],
          if (_period == _Period.all && list.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('По годам', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _YearsCard(list: list),
          ],
          const SizedBox(height: 20),
          Text('Операции (${list.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Записей нет',
              subtitle: 'Добавляйте расходы на семена, удобрения, топливо и доходы от продаж.',
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [for (final e in list) FinanceTile(entry: e)]),
            ),
        ],
      ),
    );
  }
}

/// Доходы, расходы и прибыль по каждому году — видно, как развивается хозяйство.
class _YearsCard extends StatelessWidget {
  const _YearsCard({required this.list});
  final List<FinanceEntry> list;

  @override
  Widget build(BuildContext context) {
    final years = <int, ({double income, double expense})>{};
    for (final e in list) {
      final y = years[e.date.year] ?? (income: 0.0, expense: 0.0);
      years[e.date.year] = e.isIncome
          ? (income: y.income + e.amount, expense: y.expense)
          : (income: y.income, expense: y.expense + e.amount);
    }
    final keys = years.keys.toList()..sort((a, b) => b.compareTo(a));
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final y in keys)
            ListTile(
              title: Text('$y год'),
              subtitle: Text(
                'Доходы ${fmtMoney(years[y]!.income)} · расходы ${fmtMoney(years[y]!.expense)}',
                style: muted,
              ),
              trailing: Text(
                fmtMoney(years[y]!.income - years[y]!.expense),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: years[y]!.income >= years[y]!.expense ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinanceTile extends StatelessWidget {
  const FinanceTile({super.key, required this.entry});
  final FinanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final color = entry.isIncome ? Colors.green : Colors.red;
    final sub = [
      fmtDate(entry.date),
      if (entry.fieldId != null) state.fieldName(entry.fieldId),
      if (entry.note.isNotEmpty) entry.note,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(entry.category.icon, color: color),
      ),
      title: Text(entry.category.label),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${entry.isIncome ? '+' : '−'}${fmtMoney(entry.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FinanceFormScreen(entry: entry)),
      ),
    );
  }
}

class FinanceFormScreen extends StatefulWidget {
  const FinanceFormScreen({super.key, this.entry});
  final FinanceEntry? entry;

  @override
  State<FinanceFormScreen> createState() => _FinanceFormScreenState();
}

class _FinanceFormScreenState extends State<FinanceFormScreen> {
  final _form = GlobalKey<FormState>();
  late bool _income = widget.entry?.isIncome ?? false;
  late FinanceCategory _category = widget.entry?.category ?? FinanceCategory.seeds;
  late DateTime _date = widget.entry?.date ?? dayOnly(DateTime.now());
  late String? _fieldId = widget.entry?.fieldId;
  late final _amount = TextEditingController(text: widget.entry?.amount.round().toString());
  late final _note = TextEditingController(text: widget.entry?.note);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = widget.entry ??
        FinanceEntry(id: newId(), category: _category, amount: 0, date: _date);
    e
      ..category = _category
      ..amount = parseNum(_amount.text)!
      ..date = _date
      ..fieldId = _fieldId
      ..note = _note.text.trim();
    context.read<AppState>().saveFinance(e);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fields = context.watch<AppState>().fields;
    final isEdit = widget.entry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Операция' : 'Новая операция'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDelete(context, title: 'Удалить операцию?') && context.mounted) {
                  context.read<AppState>().deleteFinance(widget.entry!.id);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Расход'), icon: Icon(Icons.arrow_upward)),
                ButtonSegment(value: true, label: Text('Доход'), icon: Icon(Icons.arrow_downward)),
              ],
              selected: {_income},
              onSelectionChanged: (s) => setState(() {
                _income = s.first;
                _category = FinanceCategory.forIncome(_income).first;
              }),
            ),
            const SizedBox(height: 16),
            Text('Категория', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in FinanceCategory.forIncome(_income))
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сумма',
                suffixText: 'сом',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final n = parseNum(v ?? '');
                return (n == null || n <= 0) ? 'Введите сумму больше 0' : null;
              },
            ),
            const SizedBox(height: 16),
            DateField(label: 'Дата', value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: fields.any((f) => f.id == _fieldId) ? _fieldId : null,
              decoration: const InputDecoration(labelText: 'Поле', prefixIcon: Icon(Icons.landscape_outlined)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Общее по хозяйству')),
                for (final f in fields) DropdownMenuItem(value: f.id, child: Text(f.name)),
              ],
              onChanged: (v) => setState(() => _fieldId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
