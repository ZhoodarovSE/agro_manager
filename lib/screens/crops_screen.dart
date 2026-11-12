import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'harvest_screen.dart';
import 'planting_form_screen.dart';

/// Модуль Crop Management: текущие посадки, история и урожайность по культурам.
class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.activePlantings;
    final done = state.plantings.where((p) => p.completed).toList()
      ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
    final yields = state.yieldByCrop().entries.toList()
      ..sort((a, b) => b.value.totalKg.compareTo(a.value.totalKg));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Культуры'),
          bottom: const TabBar(tabs: [Tab(text: 'Посадки'), Tab(text: 'Урожайность')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Посадка'),
          onPressed: () {
            if (state.fields.isEmpty) {
              showSnack(context, 'Сначала добавьте поле во вкладке «Поля»');
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantingFormScreen()));
          },
        ),
        body: TabBarView(
          children: [
            active.isEmpty && done.isEmpty
                ? const EmptyState(
                    icon: Icons.grass,
                    title: 'Посадок пока нет',
                    subtitle: 'Добавьте посадку: культура, поле, дата посадки и планируемый сбор.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (active.isNotEmpty) ...[
                        Text('Растут сейчас (${active.length})', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final p in active)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: PlantingCard(planting: p)),
                      ],
                      if (done.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Завершённые (${done.length})', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final p in done)
                                ListTile(
                                  leading: Text(p.crop.emoji, style: const TextStyle(fontSize: 24)),
                                  title: Text(p.crop.label + (p.variety.isEmpty ? '' : ' «${p.variety}»')),
                                  subtitle: Text('${state.fieldName(p.fieldId)} · '
                                      '${fmtShortDate(p.plantingDate)} — ${fmtDate(p.expectedHarvestDate)}'),
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => PlantingFormScreen(planting: p))),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
            yields.isEmpty
                ? const EmptyState(
                    icon: Icons.bar_chart,
                    title: 'Нет данных об урожае',
                    subtitle: 'Записывайте урожай — здесь появится средняя урожайность по каждой культуре.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Средняя урожайность за всё время',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (final e in yields)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Text(e.key.emoji, style: const TextStyle(fontSize: 28)),
                            title: Text(e.key.label),
                            subtitle: Text('${e.value.count} сборов · всего ${fmtKg(e.value.totalKg)}'),
                            trailing: Text(fmtYield(e.value.avgYield),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

class PlantingCard extends StatelessWidget {
  const PlantingCard({super.key, required this.planting, this.showField = true});
  final Planting planting;
  final bool showField;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final now = DateTime.now();
    final left = planting.daysUntilHarvest(now);
    final ready = left <= 0;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlantingFormScreen(planting: planting)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(planting.crop.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planting.crop.label + (planting.variety.isEmpty ? '' : ' «${planting.variety}»'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (showField)
                          Text(state.fieldName(planting.fieldId), style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(
                    ready ? 'Пора убирать' : '$left ${daysWord(left)}',
                    style: TextStyle(
                      color: ready ? Colors.orange.shade800 : cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: planting.progress(now),
                  minHeight: 8,
                  color: ready ? Colors.orange : null,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Посадка: ${fmtShortDate(planting.plantingDate)}', style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text('Сбор: ${fmtDate(planting.expectedHarvestDate)}', style: const TextStyle(fontSize: 12)),
                ],
              ),
              if (ready) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.agriculture),
                    label: const Text('Записать урожай'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HarvestFormScreen(fieldId: planting.fieldId),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
