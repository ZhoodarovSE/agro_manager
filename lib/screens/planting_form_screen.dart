import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class PlantingFormScreen extends StatefulWidget {
  const PlantingFormScreen({super.key, this.planting, this.fieldId});
  final Planting? planting;
  final String? fieldId;

  @override
  State<PlantingFormScreen> createState() => _PlantingFormScreenState();
}

class _PlantingFormScreenState extends State<PlantingFormScreen> {
  final _form = GlobalKey<FormState>();
  late String? _fieldId = widget.planting?.fieldId ?? widget.fieldId;
  late CropType _crop = widget.planting?.crop ?? CropType.potato;
  late DateTime _planted = widget.planting?.plantingDate ?? dayOnly(DateTime.now());
  late DateTime _harvest =
      widget.planting?.expectedHarvestDate ?? _planted.add(Duration(days: _crop.growingDays));
  late bool _completed = widget.planting?.completed ?? false;
  late final _variety = TextEditingController(text: widget.planting?.variety);

  @override
  void dispose() {
    _variety.dispose();
    super.dispose();
  }

  /// При смене культуры или даты посадки подсказываем дату сбора.
  void _suggestHarvest() => _harvest = _planted.add(Duration(days: _crop.growingDays));

  void _save() {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final p = widget.planting ??
        Planting(
          id: newId(),
          fieldId: _fieldId!,
          crop: _crop,
          plantingDate: _planted,
          expectedHarvestDate: _harvest,
        );
    p
      ..fieldId = _fieldId!
      ..crop = _crop
      ..variety = _variety.text.trim()
      ..plantingDate = _planted
      ..expectedHarvestDate = _harvest
      ..completed = _completed;
    state.savePlanting(p);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isEdit = widget.planting != null;
    final busy = !isEdit && _fieldId != null ? state.activePlantingFor(_fieldId!) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Посадка' : 'Новая посадка'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDelete(context, title: 'Удалить посадку?') && context.mounted) {
                  state.deletePlanting(widget.planting!.id);
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
              items: [
                for (final f in state.fields)
                  DropdownMenuItem(value: f.id, child: Text('${f.name} (${fmtHa(f.areaHa)})')),
              ],
              validator: (v) => v == null ? 'Выберите поле' : null,
              onChanged: (v) => setState(() => _fieldId = v),
            ),
            if (busy != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'На этом поле уже растёт: ${busy.crop.label}. Эта посадка будет отмечена завершённой.',
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ),
            const SizedBox(height: 16),
            Text('Культура', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in CropType.values)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.label}'),
                    selected: _crop == c,
                    onSelected: (_) => setState(() {
                      _crop = c;
                      if (!isEdit) _suggestHarvest();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _variety,
              decoration: const InputDecoration(
                labelText: 'Сорт (необязательно)',
                prefixIcon: Icon(Icons.local_florist_outlined),
              ),
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'Дата посадки',
              value: _planted,
              onChanged: (d) => setState(() {
                _planted = d;
                if (!isEdit || _harvest.isBefore(d)) _suggestHarvest();
              }),
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'Планируемый сбор',
              value: _harvest,
              firstDate: _planted,
              onChanged: (d) => setState(() => _harvest = d),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Обычно ${_crop.label.toLowerCase()} созревает за ~${_crop.growingDays} дней',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Посадка завершена'),
                subtitle: const Text('Урожай собран, культура больше не растёт'),
                value: _completed,
                onChanged: (v) => setState(() => _completed = v),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
