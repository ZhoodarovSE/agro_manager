import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'crops_screen.dart';
import 'field_form_screen.dart';
import 'harvest_screen.dart';
import 'root_shell.dart';
import 'weather_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final now = DateTime.now();
    final yearStart = DateTime(now.year);
    final yearFinances = state.financesSince(yearStart);
    final profit = state.incomeOf(yearFinances) - state.expenseOf(yearFinances);
    final yearHarvestKg =
        state.harvests.where((h) => h.date.year == now.year).fold<double>(0, (s, h) => s + h.quantityKg);
    final upcoming = state.upcomingTasks();
    final shell = RootShellState.of(context);

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AgroManager', style: TextStyle(fontWeight: FontWeight.bold)),
            if (profile.farmName.isNotEmpty)
              Text(profile.farmName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.farmerName.isEmpty ? 'Здравствуйте!' : 'Здравствуйте, ${profile.farmerName}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(fmtWeekday(now), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: WeatherSummaryCard(),
          ),
          if (state.fields.isEmpty) const _OnboardingCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(
                  icon: Icons.landscape,
                  label: 'Полей · ${fmtHa(state.totalAreaHa)}',
                  value: '${state.fields.length}',
                  onTap: () => shell?.goToTab(1),
                ),
                StatCard(
                  icon: Icons.grass,
                  label: 'Растёт культур',
                  value: '${state.activePlantings.length}',
                  color: Colors.green,
                  onTap: () => open(const CropsScreen()),
                ),
                StatCard(
                  icon: Icons.trending_up,
                  label: 'Прибыль за ${now.year}',
                  value: fmtMoney(profit),
                  color: profit >= 0 ? Colors.teal : Colors.red,
                  onTap: () => shell?.goToTab(3),
                ),
                StatCard(
                  icon: Icons.agriculture,
                  label: 'Урожай за ${now.year}',
                  value: fmtKg(yearHarvestKg),
                  color: Colors.orange,
                  onTap: () => open(const HarvestScreen()),
                ),
              ],
            ),
          ),
          const SectionHeader('Модули'),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _ModuleButton(icon: Icons.grass, label: 'Культуры', color: Colors.green, onTap: () => open(const CropsScreen())),
                _ModuleButton(icon: Icons.agriculture, label: 'Урожай', color: Colors.orange, onTap: () => open(const HarvestScreen())),
                _ModuleButton(icon: Icons.cloud, label: 'Погода', color: Colors.blue, onTap: () => open(const WeatherScreen())),
                _ModuleButton(icon: Icons.landscape, label: 'Поля', color: Colors.brown, onTap: () => shell?.goToTab(1)),
                _ModuleButton(icon: Icons.calendar_month, label: 'Календарь', color: Colors.purple, onTap: () => shell?.goToTab(2)),
                _ModuleButton(icon: Icons.account_balance_wallet, label: 'Финансы', color: Colors.teal, onTap: () => shell?.goToTab(3)),
              ],
            ),
          ),
          SectionHeader(
            'Ближайшие работы',
            trailing: TextButton(onPressed: () => shell?.goToTab(2), child: const Text('Календарь')),
          ),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('На ближайшую неделю работ нет'),
                ),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [for (final t in upcoming.take(6)) TaskTile(task: t)]),
            ),
        ],
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 88,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: cs.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Начните с добавления поля',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
              const SizedBox(height: 4),
              Text('Добавьте свои участки, чтобы планировать посадки, работы и считать урожайность.',
                  style: TextStyle(color: cs.onPrimaryContainer)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить поле'),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FieldFormScreen())),
                  ),
                  OutlinedButton(
                    onPressed: () => context.read<AppState>().loadDemoData(),
                    child: const Text('Демо-данные'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Короткая карточка погоды для главной. Сама подгружает прогноз для города из профиля.
class WeatherSummaryCard extends StatefulWidget {
  const WeatherSummaryCard({super.key});

  @override
  State<WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<WeatherSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final city = context.select<AppState, String>((s) => s.profile.city);
    final weather = context.watch<WeatherState>();
    if (weather.city != city && !weather.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<WeatherState>().load(city);
      });
    }
    final data = weather.city == city ? weather.data : null;
    final cs = Theme.of(context).colorScheme;

    Widget content;
    if (data == null) {
      content = ListTile(
        leading: weather.loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cloud_off),
        title: Text(weather.loading ? 'Загружаем погоду…' : (weather.error ?? 'Погода')),
        subtitle: Text(city),
        trailing: weather.loading
            ? null
            : IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<WeatherState>().load(city, force: true),
              ),
      );
    } else {
      final info = weatherInfo(data.current.code);
      final today = data.days.isNotEmpty ? data.days.first : null;
      final danger = data.alerts.where((a) => a.level != AlertLevel.info).toList();
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info.icon, size: 44, color: cs.primary),
                const SizedBox(width: 12),
                Text('${data.current.temperature.round()}°',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.label, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        [
                          city,
                          if (today != null) '${today.tMin.round()}…${today.tMax.round()}°',
                        ].join(' · '),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _mini(Icons.water_drop_outlined, '${data.current.humidity.round()}%'),
                _mini(Icons.umbrella_outlined, '${today?.precipProbability ?? 0}%'),
                _mini(Icons.air, '${data.current.windSpeed.toStringAsFixed(1)} м/с'),
              ],
            ),
            for (final a in danger)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(a.icon, color: a.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.title, style: TextStyle(color: a.color, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen())),
        child: content,
      ),
    );
  }

  Widget _mini(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)]),
      );
}
