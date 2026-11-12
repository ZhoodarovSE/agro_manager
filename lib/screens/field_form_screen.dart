import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class FieldFormScreen extends StatefulWidget {
  const FieldFormScreen({super.key, this.field});
  final Field? field;

  @override
  State<FieldFormScreen> createState() => _FieldFormScreenState();
}

class _FieldFormScreenState extends State<FieldFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.field?.name);
  late final _area = TextEditingController(
      text: widget.field == null ? '' : widget.field!.areaHa.toString().replaceAll('.', ','));
  late final _location = TextEditingController(text: widget.field?.location);
  late final _notes = TextEditingController(text: widget.field?.notes);
  late SoilType _soil = widget.field?.soil ?? SoilType.chernozem;
  late FieldStatus _status = widget.field?.status ?? FieldStatus.notProcessed;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final f = widget.field ?? Field(id: newId(), name: '', areaHa: 0);
    f
      ..name = _name.text.trim()
      ..areaHa = parseNum(_area.text)!
      ..soil = _soil
      ..status = _status
      ..location = _location.text.trim()
      ..notes = _notes.text.trim();
    context.read<AppState>().saveField(f);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.field == null ? 'Новое поле' : 'Редактировать поле')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название участка',
                hintText: 'Например: Участок у реки',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _area,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Площадь',
                suffixText: 'га',
                helperText: '1 га = 100 соток',
                prefixIcon: Icon(Icons.square_foot),
              ),
              validator: (v) {
                final n = parseNum(v ?? '');
                if (n == null || n <= 0) return 'Введите площадь больше 0';
                if (n > 100000) return 'Слишком большая площадь';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SoilType>(
              initialValue: _soil,
              decoration: const InputDecoration(labelText: 'Тип почвы', prefixIcon: Icon(Icons.terrain)),
              items: [for (final s in SoilType.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _soil = v!),
            ),
            const SizedBox(height: 16),
            Text('Статус обработки', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in FieldStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Расположение (необязательно)',
                hintText: 'Село, район',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Заметки (необязательно)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
