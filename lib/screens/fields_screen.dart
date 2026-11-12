import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'field_detail_screen.dart';
import 'field_form_screen.dart';

class FieldsScreen extends StatelessWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fields = [...state.fields]..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Мои поля')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Поле'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FieldFormScreen())),
      ),
      body: fields.isEmpty
          ? const EmptyState(
              icon: Icons.landscape_outlined,
              title: 'Полей пока нет',
              subtitle: 'Добавьте земельный участок: площадь, тип почвы и статус обработки.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${fields.length} участков · всего ${fmtHa(state.totalAreaHa)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                for (final f in fields) FieldCard(field: f),
              ],
            ),
    );
  }
}

class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.field});
  final Field field;

  @override
  Widget build(BuildContext context) {
    final planting = context.watch<AppState>().activePlantingFor(field.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FieldDetailScreen(fieldId: field.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: field.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(planting?.crop.emoji ?? '🟫', style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtHa(field.areaHa)} · ${field.soil.label}'
                      '${planting != null ? ' · ${planting.crop.label}' : ''}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    StatusChip(status: field.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final FieldStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.label,
          style: TextStyle(fontSize: 12, color: status.color, fontWeight: FontWeight.w600)),
    );
  }
}
