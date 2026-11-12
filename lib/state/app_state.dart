import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'demo_data.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Всё состояние хозяйства. Хранится локально на телефоне (SharedPreferences, JSON).
class AppState extends ChangeNotifier {
  static const storageKey = 'agro_manager_data_v1';

  final List<Field> fields = [];
  final List<Planting> plantings = [];
  final List<FarmTask> tasks = [];
  final List<FinanceEntry> finances = [];
  final List<Harvest> harvests = [];
  Profile profile = Profile();

  bool loaded = false;

  // ---------- Загрузка / сохранение ----------

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('AgroManager: не удалось прочитать данные: $e');
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Map<String, dynamic> toJson() => {
        'fields': fields.map((e) => e.toJson()).toList(),
        'plantings': plantings.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'finances': finances.map((e) => e.toJson()).toList(),
        'harvests': harvests.map((e) => e.toJson()).toList(),
        'profile': profile.toJson(),
      };

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    fields
      ..clear()
      ..addAll(list('fields', Field.fromJson));
    plantings
      ..clear()
      ..addAll(list('plantings', Planting.fromJson));
    tasks
      ..clear()
      ..addAll(list('tasks', FarmTask.fromJson));
    finances
      ..clear()
      ..addAll(list('finances', FinanceEntry.fromJson));
    harvests
      ..clear()
      ..addAll(list('harvests', Harvest.fromJson));
    profile = j['profile'] is Map<String, dynamic>
        ? Profile.fromJson(j['profile'] as Map<String, dynamic>)
        : Profile();
  }

  static void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  // ---------- Поля ----------

  Field? fieldById(String? id) {
    if (id == null) return null;
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  String fieldName(String? id) => fieldById(id)?.name ?? '—';

  double get totalAreaHa => fields.fold(0, (s, f) => s + f.areaHa);

  void saveField(Field f) {
    _upsert(fields, f, (e) => e.id);
    _changed();
  }

  /// Удаляет поле вместе с его посадками, работами и урожаем.
  /// Финансовые записи остаются, но отвязываются от поля.
  void deleteField(String id) {
    fields.removeWhere((f) => f.id == id);
    plantings.removeWhere((p) => p.fieldId == id);
    tasks.removeWhere((t) => t.fieldId == id);
    harvests.removeWhere((h) => h.fieldId == id);
    for (final e in finances) {
      if (e.fieldId == id) e.fieldId = null;
    }
    _changed();
  }

  // ---------- Посадки ----------

  List<Planting> get activePlantings => plantings.where((p) => !p.completed).toList()
    ..sort((a, b) => a.expectedHarvestDate.compareTo(b.expectedHarvestDate));

  Planting? activePlantingFor(String fieldId) {
    for (final p in activePlantings) {
      if (p.fieldId == fieldId) return p;
    }
    return null;
  }

  void savePlanting(Planting p) {
    final isNew = !plantings.any((e) => e.id == p.id);
    if (isNew && !p.completed) {
      // На поле одна текущая культура: предыдущие посадки закрываем.
      for (final other in plantings) {
        if (other.fieldId == p.fieldId && !other.completed) other.completed = true;
      }
      fieldById(p.fieldId)?.status = FieldStatus.sown;
    }
    _upsert(plantings, p, (e) => e.id);
    _changed();
  }

  void deletePlanting(String id) {
    plantings.removeWhere((p) => p.id == id);
    _changed();
  }

  // ---------- Календарь ----------

  List<FarmTask> tasksOn(DateTime day) => tasks.where((t) => sameDay(t.date, day)).toList()
    ..sort((a, b) => a.type.index.compareTo(b.type.index));

  /// Невыполненные работы: просроченные и на ближайшие [days] дней.
  List<FarmTask> upcomingTasks({int days = 7}) {
    final limit = dayOnly(DateTime.now()).add(Duration(days: days + 1));
    return tasks.where((t) => !t.done && t.date.isBefore(limit)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void saveTask(FarmTask t) {
    _upsert(tasks, t, (e) => e.id);
    _changed();
  }

  void toggleTask(FarmTask t) {
    t.done = !t.done;
    _changed();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _changed();
  }

  // ---------- Финансы ----------

  void saveFinance(FinanceEntry e) {
    _upsert(finances, e, (x) => x.id);
    _changed();
  }

  void deleteFinance(String id) {
    finances.removeWhere((e) => e.id == id);
    _changed();
  }

  List<FinanceEntry> financesSince(DateTime? from) =>
      finances.where((e) => from == null || !e.date.isBefore(from)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  double incomeOf(Iterable<FinanceEntry> list) =>
      list.where((e) => e.isIncome).fold(0, (s, e) => s + e.amount);

  double expenseOf(Iterable<FinanceEntry> list) =>
      list.where((e) => !e.isIncome).fold(0, (s, e) => s + e.amount);

  // ---------- Урожай ----------

  List<Harvest> get harvestsSorted => [...harvests]..sort((a, b) => b.date.compareTo(a.date));

  /// Сохраняет урожай. Если [completePlanting] задан — закрывает посадку и меняет статус поля.
  void saveHarvest(Harvest h, {Planting? completePlanting}) {
    _upsert(harvests, h, (e) => e.id);
    if (completePlanting != null) {
      completePlanting.completed = true;
      fieldById(completePlanting.fieldId)?.status = FieldStatus.harvested;
    }
    _changed();
  }

  void deleteHarvest(String id) {
    harvests.removeWhere((h) => h.id == id);
    _changed();
  }

  /// Средняя урожайность по культурам (кг/га), взвешенная по площади.
  Map<CropType, ({double avgYield, double totalKg, int count})> yieldByCrop() {
    final result = <CropType, ({double avgYield, double totalKg, int count})>{};
    for (final crop in CropType.values) {
      final list = harvests.where((h) => h.crop == crop && h.areaHa > 0).toList();
      if (list.isEmpty) continue;
      final kg = list.fold<double>(0, (s, h) => s + h.quantityKg);
      final area = list.fold<double>(0, (s, h) => s + h.areaHa);
      result[crop] = (avgYield: kg / area, totalKg: kg, count: list.length);
    }
    return result;
  }

  // ---------- Профиль ----------

  void saveProfile(Profile p) {
    profile = p;
    _changed();
  }

  void clearAll() {
    fields.clear();
    plantings.clear();
    tasks.clear();
    finances.clear();
    harvests.clear();
    _changed();
  }

  /// Заполняет приложение примерным хозяйством с историей с 2023 года (см. demo_data.dart).
  void loadDemoData() {
    clearAll();
    fillDemoData(this, DateTime.now());
    _changed();
  }
}
