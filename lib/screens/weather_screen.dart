import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherState>().load(context.read<AppState>().profile.city);
    });
  }

  Future<void> _pickCity() async {
    final state = context.read<AppState>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final c in kCities)
            ListTile(
              title: Text(c.name),
              subtitle: Text(c.region),
              trailing: c.name == state.profile.city ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, c.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    state.saveProfile(state.profile..city = picked);
    context.read<WeatherState>().load(picked);
  }

  @override
  Widget build(BuildContext context) {
    final city = context.select<AppState, String>((s) => s.profile.city);
    final weather = context.watch<WeatherState>();
    final data = weather.city == city ? weather.data : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Погода'),
        actions: [
          TextButton.icon(onPressed: _pickCity, icon: const Icon(Icons.place_outlined), label: Text(city)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<WeatherState>().load(city, force: true),
        child: data == null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: weather.loading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              const Icon(Icons.cloud_off, size: 64),
                              const SizedBox(height: 12),
                              Text(weather.error ?? 'Нет данных'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => context.read<WeatherState>().load(city, force: true),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                  ),
                ],
              )
            : _WeatherBody(data: data),
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.data});
  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = weatherInfo(data.current.code);
    final c = data.current;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(info.icon, size: 64, color: cs.onPrimaryContainer),
                Text('${c.temperature.round()}°C',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: cs.onPrimaryContainer)),
                Text(info.label, style: TextStyle(fontSize: 18, color: cs.onPrimaryContainer)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric(context, Icons.water_drop_outlined, '${c.humidity.round()}%', 'Влажность'),
                    _metric(context, Icons.umbrella_outlined, '${c.precipitation.toStringAsFixed(1)} мм', 'Осадки'),
                    _metric(context, Icons.air, '${c.windSpeed.toStringAsFixed(1)} м/с', 'Ветер'),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final a in data.alerts)
          Card(
            margin: const EdgeInsets.only(top: 12),
            color: a.color.withValues(alpha: 0.12),
            child: ListTile(
              leading: Icon(a.icon, color: a.color),
              title: Text(a.title, style: TextStyle(color: a.color, fontWeight: FontWeight.bold)),
              subtitle: Text(a.message),
            ),
          ),
        const SizedBox(height: 20),
        Text('Прогноз на ${data.days.length} дней', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < data.days.length; i++) _dayRow(context, data.days[i], i),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Данные: Open-Meteo · обновлено ${TimeOfDay.fromDateTime(data.fetchedAt).format(context)}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, IconData icon, String value, String label) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Icon(icon, color: color),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _dayRow(BuildContext context, DayForecast d, int i) {
    final info = weatherInfo(d.code);
    final frost = d.tMin <= 0;
    final label = i == 0 ? 'Сегодня' : (i == 1 ? 'Завтра' : fmtWeekday(d.date));
    return ListTile(
      leading: Icon(info.icon),
      title: Text(label),
      subtitle: Text('${info.label} · ${d.precipProbability}% · ${d.precipitation.toStringAsFixed(1)} мм'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (frost) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.ac_unit, color: Colors.blue, size: 18)),
          Text('${d.tMin.round()}° / ', style: TextStyle(color: frost ? Colors.blue : null)),
          Text('${d.tMax.round()}°', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
