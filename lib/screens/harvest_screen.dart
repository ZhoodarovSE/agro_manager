import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class HarvestScreen extends StatelessWidget {
  const HarvestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.harvestsSorted;
    final year = DateTime.now().year;
    final thisYear = list.where((h) => h.date.year == year);
    final yearKg = thisYear.fold<double>(0, (s, h) => s + h.quantityKg);
    final yearArea = thisYear.fold<double>(0, (s, h) => s + h.areaHa);

    // Группируем историю по годам.
    final byYear = <int, List<Harvest>>{};
    for (final h in list) {
      (byYear[h.date.year] ??= []).add(h);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Урожай')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Записать'),
        onPressed: () {
          if (state.fields.isEmpty) {
            showSnack(context, 'Сначала добавьте поле во вкладке «Поля»');
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HarvestFormScreen()));
        },
      ),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.agriculture,
              title: 'Урожай ещё не записан',
              subtitle: 'Записывайте каждый сбор — приложение посчитает урожайность с гектара.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                          icon: Icons.scale, label: 'Собрано в $year', value: fmtKg(yearKg), color: Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.speed,
                        label: 'Ср. урожайность',
                        value: yearArea > 0 ? fmtYield(yearKg / yearArea) : '—',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                for (final entry in byYear.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Text('${entry.key} год', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(children: [for (final h in entry.value) HarvestTile(harvest: h)]),
                  ),
                ],
              ],
            ),
    );
  }
}

class HarvestTile extends StatelessWidget {
  const HarvestTile({super.key, required this.harvest, this.showField = true});
  final Harvest harvest;
  final bool showField;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ListTile(
      leading: Text(harvest.crop.emoji, style: const TextStyle(fontSize: 26)),
      title: Text('${harvest.crop.label} · ${fmtKg(harvest.quantityKg)}'),
      subtitle: Text([
        fmtDate(harvest.date),
        if (showField) state.fieldName(harvest.fieldId),
        fmtHa(harvest.areaHa),
      ].join(' · ')),
      trailing: Text(fmtYield(harvest.yieldPerHa), style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HarvestFormScreen(harvest: harvest)),
      ),
    );
  }
}

class HarvestFormScreen extends StatefulWidget {
  const HarvestFormScreen({super.key, this.harvest, this.fieldId});
  final Harvest? harvest;
  final String? fieldId;

  @override
  State<HarvestFormScreen> createState() => _HarvestFormScreenState();
}

class _HarvestFormScreenState extends State<HarvestFormScreen> {
  final _form = GlobalKey<FormState>();
  late String? _fieldId = widget.harvest?.fieldId ?? widget.fieldId;
  late CropType _crop = widget.harvest?.crop ?? CropType.potato;
  late DateTime _date = widget.harvest?.date ?? dayOnly(DateTime.now());
  late final _kg = TextEditingController(
      text: widget.harvest == null ? '' : widget.harvest!.quantityKg.round().toString());
  late final _area = TextEditingController(
      text: widget.harvest == null ? '' : widget.harvest!.areaHa.toString().replaceAll('.', ','));
  late final _note = TextEditingController(text: widget.harvest?.note);
  bool _completePlanting = true;

  @override
  void initState() {
    super.initState();
    if (widget.harvest == null && _fieldId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onFieldChanged(_fieldId));
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    _area.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Подставляем площадь поля и культуру, которая на нём растёт.
  void _onFieldChanged(String? id) {
    final state = context.read<AppState>();
    setState(() {
      _fieldId = id;
      final f = state.fieldById(id);
      if (f != null) _area.text = f.areaHa.toString().replaceAll('.', ',');
      final p = id == null ? null : state.activePlantingFor(id);
      if (p != null) _crop = p.crop;
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final h = widget.harvest ??
        Harvest(id: newId(), fieldId: _fieldId!, crop: _crop, date: _date, quantityKg: 0, areaHa: 0);
    h
      ..fieldId = _fieldId!
      ..crop = _crop
      ..date = _date
      ..quantityKg = parseNum(_kg.text)!
      ..areaHa = parseNum(_area.text)!
      ..note = _note.text.trim();
    final planting = widget.harvest == null ? state.activePlantingFor(_fieldId!) : null;
    state.saveHarvest(h, completePlanting: _completePlanting ? planting : null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isEdit = widget.harvest != null;
    final kg = parseNum(_kg.text);
    final area = parseNum(_area.text);
    final preview = (kg != null && area != null && area > 0) ? kg / area : null;
    final active = !isEdit && _fieldId != null ? state.activePlantingFor(_fieldId!) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Урожай' : 'Записать урожай'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDelete(context, title: 'Удалить запись урожая?') && context.mounted) {
                  state.deleteHarvest(widget.harvest!.id);
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
            DropdownButtonFormField<String>(
              initialValue: state.fields.any((f) => f.id == _fieldId) ? _fieldId : null,
              decoration: const InputDecoration(labelText: 'Поле', prefixIcon: Icon(Icons.landscape_outlined)),
              items: [for (final f in state.fields) DropdownMenuItem(value: f.id, child: Text(f.name))],
              validator: (v) => v == null ? 'Выберите поле' : null,
              onChanged: _onFieldChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CropType>(
              key: ValueKey(_crop),
              initialValue: _crop,
              decoration: const InputDecoration(labelText: 'Культура', prefixIcon: Icon(Icons.grass)),
              items: [
                for (final c in CropType.values) DropdownMenuItem(value: c, child: Text('${c.emoji} ${c.label}')),
              ],
              onChanged: (v) => setState(() => _crop = v!),
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'Дата сбора',
              value: _date,
              lastDate: DateTime.now().add(const Duration(days: 1)),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _kg,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Собрано', suffixText: 'кг'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = parseNum(v ?? '');
                      return (n == null || n <= 0) ? 'Больше 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _area,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'С площади', suffixText: 'га'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = parseNum(v ?? '');
                      return (n == null || n <= 0) ? 'Больше 0' : null;
                    },
                  ),
                ),
              ],
            ),
            if (preview != null)
              Card(
                margin: const EdgeInsets.only(top: 12),
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text('Урожайность: ${fmtYield(preview)}'),
                  subtitle: Text('${fmtKg(preview)} с гектара'),
                ),
              ),
            if (active != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _completePlanting,
                onChanged: (v) => setState(() => _completePlanting = v ?? false),
                title: Text('Завершить посадку «${active.crop.label}»'),
                subtitle: const Text('Статус поля станет «Урожай собран»'),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
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
