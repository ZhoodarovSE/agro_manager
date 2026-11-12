import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'crops_screen.dart';
import 'harvest_screen.dart';
import 'weather_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: state.profile.farmerName);
    final farm = TextEditingController(text: state.profile.farmName);
    var city = state.profile.city;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Профиль'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Ваше имя'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: farm,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Название хозяйства'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: city,
                  decoration: const InputDecoration(labelText: 'Город для погоды'),
                  items: [for (final c in kCities) DropdownMenuItem(value: c.name, child: Text(c.name))],
                  onChanged: (v) => setLocal(() => city = v ?? city),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (saved == true) {
      state.saveProfile(Profile(farmerName: name.text.trim(), farmName: farm.text.trim(), city: city));
    }
    // Контроллеры не освобождаем сразу: диалог ещё анимирует закрытие и использует их.
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final cs = Theme.of(context).colorScheme;

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              child: Text(
                p.farmerName.isEmpty ? '👨‍🌾' : p.farmerName.characters.first.toUpperCase(),
                style: TextStyle(fontSize: 32, color: cs.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(p.farmerName.isEmpty ? 'Фермер' : p.farmerName,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (p.farmName.isNotEmpty)
            Text(p.farmName, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          Text('📍 ${p.city}', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Изменить профиль'),
            ),
          ),
          const SectionHeader('Хозяйство'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.landscape_outlined),
                    title: const Text('Земля'),
                    trailing: Text('${state.fields.length} полей · ${fmtHa(state.totalAreaHa)}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.grass),
                    title: const Text('Культуры'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(const CropsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.agriculture),
                    title: const Text('Урожай'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(const HarvestScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Погода'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(const WeatherScreen()),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Данные'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: const Text('Загрузить демо-данные'),
                    subtitle: const Text('Пример хозяйства для знакомства с приложением'),
                    onTap: () async {
                      final ok = state.fields.isEmpty ||
                          await confirmDelete(context,
                              title: 'Заменить данные?',
                              message: 'Текущие поля, работы, финансы и урожай будут заменены примером.');
                      if (ok) {
                        state.loadDemoData();
                        if (context.mounted) showSnack(context, 'Демо-данные загружены');
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                    title: Text('Удалить все данные', style: TextStyle(color: cs.error)),
                    onTap: () async {
                      if (await confirmDelete(context,
                          title: 'Удалить все данные?',
                          message: 'Поля, посадки, работы, финансы и урожай будут удалены безвозвратно.')) {
                        state.clearAll();
                        if (context.mounted) showSnack(context, 'Данные удалены');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('AgroManager 1.0 · Smart Farming Assistant',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Text('Данные хранятся только на этом телефоне',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
