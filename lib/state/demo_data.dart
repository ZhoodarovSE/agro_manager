import 'dart:math';

import '../models/models.dart';
import 'app_state.dart';

/// Демо-хозяйство с историей с весны 2023 года по сегодняшний день.
///
/// Всё строится от плана севооборота: для каждой посадки создаются работы,
/// расходы, запись урожая и продажи. Что уже прошло — выполнено и записано,
/// что идёт сейчас — активная посадка, что будет — работы в календаре.
/// Генератор детерминированный: при каждой загрузке данные одинаковые.
void fillDemoData(AppState s, DateTime now) {
  final today = dayOnly(now);
  final rnd = Random(2023);
  double vary(double spread) => 1 + (rnd.nextDouble() * 2 - 1) * spread;

  // ---------- Поля ----------
  final river = Field(
      id: newId(),
      name: 'Участок у реки',
      areaHa: 2.5,
      soil: SoilType.chernozem,
      location: 'Чуйская обл., Сокулукский р-н',
      notes: 'Собственный участок, полив из арыка');
  final upper = Field(
      id: newId(),
      name: 'Верхнее поле',
      areaHa: 4,
      soil: SoilType.serozem,
      location: 'Чуйская обл., Аламединский р-н',
      notes: 'Зерновой севооборот, полив ограничен');
  final garden = Field(
      id: newId(),
      name: 'Огород',
      areaHa: 0.3,
      soil: SoilType.loam,
      location: 'Возле дома',
      notes: 'Овощи на продажу на базаре');
  final lower = Field(
      id: newId(),
      name: 'Нижнее поле',
      areaHa: 6,
      soil: SoilType.chestnut,
      location: 'Чуйская обл., Ысык-Атинский р-н',
      notes: 'Взято в аренду в 2024 году');
  final alfalfaField = Field(
      id: newId(),
      name: 'Люцерновое поле',
      areaHa: 3,
      soil: SoilType.sandyLoam,
      location: 'Чуйская обл., Кант',
      notes: 'Многолетняя люцерна на сено, посеяна в 2025 году');
  s.fields.addAll([river, upper, garden, lower, alfalfaField]);

  // ---------- План севооборота ----------
  DateTime dt(int y, int m, int d) => DateTime(y, m, d);
  final plan = <_Plan>[
    _Plan(river, CropType.potato, 'Пикассо', dt(2023, 4, 15), dt(2023, 8, 25)),
    _Plan(river, CropType.beans, 'Лопатка', dt(2024, 5, 10), dt(2024, 8, 30)),
    _Plan(river, CropType.potato, 'Гала', dt(2025, 4, 12), dt(2025, 8, 28)),
    _Plan(river, CropType.corn, 'Кыргызстанская 26', dt(2026, 5, 5), dt(2026, 9, 25)),
    _Plan(upper, CropType.barley, 'Нутанс', dt(2023, 3, 25), dt(2023, 7, 5)),
    _Plan(upper, CropType.wheat, 'Интенсивная (озимая)', dt(2023, 10, 5), dt(2024, 7, 12)),
    _Plan(upper, CropType.sunflower, 'Лакомка', dt(2025, 4, 25), dt(2025, 9, 20)),
    _Plan(upper, CropType.wheat, 'Безостая 100 (озимая)', dt(2025, 10, 3), dt(2026, 7, 10)),
    _Plan(upper, CropType.wheat, 'Интенсивная (озимая)', dt(2026, 10, 5), dt(2027, 7, 12)),
    _Plan(garden, CropType.tomato, 'Бычье сердце', dt(2023, 5, 5), dt(2023, 8, 20)),
    _Plan(garden, CropType.cabbage, 'Слава', dt(2024, 4, 25), dt(2024, 9, 10)),
    _Plan(garden, CropType.tomato, 'Де Барао', dt(2025, 5, 3), dt(2025, 8, 25)),
    _Plan(garden, CropType.onion, 'Халцедон', dt(2026, 4, 5), dt(2026, 8, 15)),
    _Plan(lower, CropType.corn, 'Кыргызстанская 26', dt(2024, 5, 1), dt(2024, 10, 5)),
    _Plan(lower, CropType.sugarBeet, 'Каракол', dt(2025, 4, 8), dt(2025, 10, 20)),
    _Plan(lower, CropType.beans, 'Ак-Буурчак', dt(2026, 5, 8), dt(2026, 9, 1)),
    _Plan(lower, CropType.barley, 'Джерен (озимый)', dt(2026, 10, 12), dt(2027, 6, 28)),
    _Plan(lower, CropType.potato, 'Пикассо', dt(2027, 4, 14), dt(2027, 8, 26)),
    _Plan(river, CropType.potato, 'Гала', dt(2027, 4, 10), dt(2027, 8, 25)),
  ];

  // Урожайность по годам: 2023 — засушливое лето, 2026 — удачный год.
  const yearYield = {2023: 0.88, 2024: 1.05, 2025: 0.97, 2026: 1.08};
  double inflation(int year) => pow(1.07, max(0, year - 2023)).toDouble();
  final horizon = today.add(const Duration(days: 60)); // дальше в календарь не заглядываем

  void expense(FinanceCategory c, double amount, DateTime date, Field? f, String note) {
    if (date.isAfter(today) || amount <= 0) return;
    s.finances.add(FinanceEntry(
      id: newId(),
      category: c,
      amount: (amount * inflation(date.year) * vary(0.06) / 100).round() * 100,
      date: date,
      fieldId: f?.id,
      note: note,
    ));
  }

  void task(TaskType type, DateTime date, Field? f, String note) {
    if (date.isAfter(horizon)) return;
    s.tasks.add(FarmTask(id: newId(), type: type, date: date, fieldId: f?.id, note: note, done: date.isBefore(today)));
  }

  /// Записывает урожай и продажи (часть сразу, часть позже по лучшей цене).
  void harvestAndSell(Field f, CropType crop, DateTime date, double kgPerHa, String note) {
    final eco = _eco[crop]!;
    final kg = (f.areaHa * kgPerHa * (yearYield[date.year] ?? 1) * vary(0.08) / 10).round() * 10.0;
    s.harvests.add(Harvest(
        id: newId(), fieldId: f.id, crop: crop, date: date, quantityKg: kg, areaHa: f.areaHa, note: note));
    final price = eco.price * inflation(date.year);
    final parts = kg > 5000 ? [(0.6, 3 + rnd.nextInt(8)), (0.32, 30 + rnd.nextInt(30))] : [(0.9, 2 + rnd.nextInt(6))];
    for (final (share, after) in parts) {
      final d = date.add(Duration(days: after));
      if (d.isAfter(today)) continue;
      final soldKg = (kg * share / 10).round() * 10;
      final p = price * vary(0.07) * (after > 20 ? 1.08 : 1); // позже — дороже
      s.finances.add(FinanceEntry(
        id: newId(),
        category: FinanceCategory.sale,
        amount: (soldKg * p / 100).round() * 100,
        date: d,
        fieldId: f.id,
        note: '${crop.label}: $soldKg кг ${eco.buyer}',
      ));
    }
  }

  for (final p in plan) {
    final f = p.field;
    final eco = _eco[p.crop]!;
    final a = f.areaHa;
    DateTime at(int days) => p.plant.add(Duration(days: days));

    if (p.plant.isAfter(today)) {
      // Будущая посадка — только подготовительные работы в календаре.
      task(TaskType.planting, p.plant, f, 'Посадка: ${p.crop.label}, ${p.variety}');
      continue;
    }

    final completed = !p.harvest.isAfter(today);
    s.plantings.add(Planting(
      id: newId(),
      fieldId: f.id,
      crop: p.crop,
      variety: p.variety,
      plantingDate: p.plant,
      expectedHarvestDate: p.harvest,
      completed: completed,
    ));

    // Работы.
    task(TaskType.other, at(-6), f, 'Вспашка и боронование');
    task(TaskType.planting, p.plant, f, '${p.crop.label}, сорт «${p.variety}»');
    task(TaskType.fertilizing, at(25), f, eco.fertNote);
    task(TaskType.treatment, at(45), f, eco.treatNote);
    final growDays = p.harvest.difference(p.plant).inDays;
    if (eco.irrigated) {
      for (var d = 14; d < growDays - 10; d += 18) {
        task(TaskType.watering, at(d), f, d == 14 ? 'Первый полив по бороздам' : 'Полив по бороздам');
      }
    } else if (growDays > 200) {
      // Озимые: весенняя подкормка и полив.
      task(TaskType.fertilizing, DateTime(p.harvest.year, 3, 20), f, 'Весенняя подкормка азотом');
      task(TaskType.watering, DateTime(p.harvest.year, 5, 10), f, 'Вегетационный полив');
    }
    task(TaskType.harvesting, p.harvest, f, 'Уборка: ${p.crop.label}');

    // Расходы.
    expense(FinanceCategory.fuel, a * eco.fuel * 0.6, at(-6), f, 'Дизель: вспашка и посев');
    expense(FinanceCategory.seeds, a * eco.seeds, at(-3), f, 'Семена: ${p.crop.label} «${p.variety}»');
    expense(FinanceCategory.labor, a * eco.labor * 0.4, p.plant, f, 'Оплата работникам за посадку');
    expense(FinanceCategory.fertilizer, a * eco.fert, at(24), f, eco.fertNote);
    expense(FinanceCategory.pesticides, a * eco.pest, at(44), f, eco.treatNote);
    if (eco.irrigated) expense(FinanceCategory.water, a * eco.water, at(35), f, 'Оплата водопользования (АВП)');
    if (completed) {
      expense(FinanceCategory.fuel, a * eco.fuel * 0.4, p.harvest, f, 'Дизель: уборка и вывоз');
      expense(FinanceCategory.labor, a * eco.labor * 0.6, p.harvest, f, 'Оплата работникам за уборку');
      harvestAndSell(f, p.crop, p.harvest, eco.yieldKgHa, p.harvest.year == 2023 ? 'Засушливое лето' : '');
    }
  }

  // ---------- Люцерна: одна посадка, несколько укосов в год ----------
  final alfalfaSown = dt(2025, 4, 15);
  final cuts = [dt(2025, 7, 10), dt(2025, 9, 5), dt(2026, 5, 25), dt(2026, 7, 15), dt(2026, 9, 8), dt(2027, 5, 25), dt(2027, 7, 15)];
  if (!alfalfaSown.isAfter(today)) {
    final next = cuts.firstWhere((c) => c.isAfter(today), orElse: () => cuts.last);
    s.plantings.add(Planting(
        id: newId(),
        fieldId: alfalfaField.id,
        crop: CropType.alfalfa,
        variety: 'Кыргызская 1 (многолетняя)',
        plantingDate: alfalfaSown,
        expectedHarvestDate: next));
    final eco = _eco[CropType.alfalfa]!;
    final a = alfalfaField.areaHa;
    task(TaskType.planting, alfalfaSown, alfalfaField, 'Посев люцерны');
    expense(FinanceCategory.seeds, a * eco.seeds, alfalfaSown.subtract(const Duration(days: 3)), alfalfaField,
        'Семена люцерны «Кыргызская 1»');
    expense(FinanceCategory.fertilizer, a * eco.fert, dt(2025, 4, 10), alfalfaField, eco.fertNote);
    for (var i = 0; i < cuts.length; i++) {
      final c = cuts[i];
      task(TaskType.watering, c.subtract(const Duration(days: 20)), alfalfaField, 'Полив перед укосом');
      task(TaskType.harvesting, c, alfalfaField, 'Укос люцерны на сено');
      if (c.isAfter(today)) continue;
      expense(FinanceCategory.water, a * eco.water, c.subtract(const Duration(days: 20)), alfalfaField, 'Оплата воды');
      expense(FinanceCategory.fuel, a * eco.fuel, c, alfalfaField, 'Дизель: косилка и пресс-подборщик');
      expense(FinanceCategory.labor, a * eco.labor, c, alfalfaField, 'Укладка тюков');
      final first = i == 0;
      harvestAndSell(alfalfaField, CropType.alfalfa, c, eco.yieldKgHa * (first ? 0.6 : 1),
          first ? 'Первый укос в год посева' : 'Сено в тюках');
    }
  }

  // ---------- Общие расходы и доходы хозяйства по годам ----------
  for (var y = 2023; y <= today.year; y++) {
    expense(FinanceCategory.equipment, 38000, dt(y, 2, 12), null, 'Ремонт трактора МТЗ-82 к сезону');
    expense(FinanceCategory.otherExpense, 4500, dt(y, 10, 15), null, 'Земельный налог');
    final subsidy = dt(y, 3, 18);
    if (!subsidy.isAfter(today)) {
      s.finances.add(FinanceEntry(
          id: newId(),
          category: FinanceCategory.subsidy,
          amount: (18000 + (y - 2023) * 4000).toDouble(),
          date: subsidy,
          note: 'Государственная субсидия на семена и удобрения'));
    }
    if (y >= 2024) {
      expense(FinanceCategory.otherExpense, 27000, dt(y, 1, 20), lower, 'Аренда Нижнего поля (6 га) на год');
      final service = dt(y, 9, 20);
      if (!service.isAfter(today)) {
        s.finances.add(FinanceEntry(
            id: newId(),
            category: FinanceCategory.otherIncome,
            amount: 22000 + (y - 2024) * 3000,
            date: service,
            note: 'Вспашка участков соседям своим трактором'));
      }
    }
  }
  expense(FinanceCategory.equipment, 172000, dt(2025, 3, 3), null, 'Покупка культиватора КРН-4,2');
  expense(FinanceCategory.equipment, 64000, dt(2026, 2, 20), null, 'Капельная лента и насос для огорода');

  // ---------- Ближайшие работы (относительно сегодняшнего дня) ----------
  DateTime d(int days) => today.add(Duration(days: days));
  final coldSeason = today.month >= 10 || today.month <= 2;
  if (coldSeason) {
    s.tasks.addAll([
      FarmTask(id: newId(), type: TaskType.fertilizing, date: d(-2), fieldId: garden.id, note: 'Внести перепревший навоз, 3 т'),
      FarmTask(id: newId(), type: TaskType.watering, date: d(0), fieldId: upper.id, note: 'Влагозарядковый полив озимых'),
      FarmTask(id: newId(), type: TaskType.other, date: d(2), fieldId: river.id, note: 'Вспашка зяби на 25 см'),
      FarmTask(id: newId(), type: TaskType.treatment, date: d(5), fieldId: lower.id, note: 'Защита озимого ячменя от грызунов'),
      FarmTask(id: newId(), type: TaskType.other, date: d(18), note: 'Закупить семенной картофель на весну'),
    ]);
  } else {
    s.tasks.addAll([
      FarmTask(id: newId(), type: TaskType.watering, date: d(-1), fieldId: garden.id, note: 'Полив по капельной ленте'),
      FarmTask(id: newId(), type: TaskType.watering, date: d(0), fieldId: river.id, note: 'Полив по бороздам'),
      FarmTask(id: newId(), type: TaskType.fertilizing, date: d(2), fieldId: lower.id, note: 'Подкормка селитрой, 100 кг/га'),
      FarmTask(id: newId(), type: TaskType.treatment, date: d(4), fieldId: river.id, note: 'Обработка от вредителей'),
      FarmTask(id: newId(), type: TaskType.watering, date: d(7), fieldId: alfalfaField.id, note: 'Полив люцерны'),
    ]);
  }

  // ---------- Статусы полей ----------
  for (final f in s.fields) {
    final active = s.activePlantingFor(f.id);
    final lastHarvest = s.harvests
        .where((h) => h.fieldId == f.id)
        .fold<DateTime?>(null, (m, h) => m == null || h.date.isAfter(m) ? h.date : m);
    if (active != null) {
      f.status = today.difference(active.plantingDate).inDays < 30 ? FieldStatus.sown : FieldStatus.growing;
    } else if (lastHarvest != null && today.difference(lastHarvest).inDays < 120) {
      f.status = FieldStatus.harvested;
    } else {
      f.status = FieldStatus.plowed;
    }
  }

  s.profile = Profile(
    farmerName: s.profile.farmerName.isEmpty ? 'Азамат' : s.profile.farmerName,
    farmName: s.profile.farmName.isEmpty ? 'Крестьянское хозяйство «Ак-Жол»' : s.profile.farmName,
    city: s.profile.city,
  );
}

class _Plan {
  _Plan(this.field, this.crop, this.variety, this.plant, this.harvest);
  final Field field;
  final CropType crop;
  final String variety;
  final DateTime plant;
  final DateTime harvest;
}

/// Затраты на 1 га (сом, цены 2023 года), урожайность и цена продажи.
class _Eco {
  const _Eco({
    required this.seeds,
    required this.fert,
    required this.pest,
    required this.water,
    required this.fuel,
    required this.labor,
    required this.yieldKgHa,
    required this.price,
    required this.buyer,
    this.irrigated = true,
    this.fertNote = 'Аммиачная селитра, 150 кг/га',
    this.treatNote = 'Обработка гербицидом',
  });

  final double seeds, fert, pest, water, fuel, labor, yieldKgHa, price;
  final String buyer, fertNote, treatNote;
  final bool irrigated;
}

const _eco = <CropType, _Eco>{
  CropType.potato: _Eco(seeds: 70000, fert: 15000, pest: 9000, water: 6000, fuel: 12000, labor: 28000, yieldKgHa: 22000, price: 18,
      buyer: 'оптовикам', treatNote: 'Против колорадского жука и фитофторы'),
  CropType.beans: _Eco(seeds: 18000, fert: 6000, pest: 5000, water: 5000, fuel: 8000, labor: 15000, yieldKgHa: 2200, price: 85,
      buyer: 'экспортёру', fertNote: 'Суперфосфат, 100 кг/га'),
  CropType.corn: _Eco(seeds: 9000, fert: 14000, pest: 4000, water: 6000, fuel: 11000, labor: 7000, yieldKgHa: 8500, price: 15,
      buyer: 'на комбикормовый завод'),
  CropType.barley: _Eco(seeds: 4500, fert: 7000, pest: 2500, water: 2500, fuel: 9000, labor: 4000, yieldKgHa: 3600, price: 14,
      buyer: 'на элеватор', irrigated: false),
  CropType.wheat: _Eco(seeds: 5500, fert: 9000, pest: 3000, water: 3000, fuel: 9500, labor: 4500, yieldKgHa: 4200, price: 17,
      buyer: 'на элеватор', irrigated: false),
  CropType.sunflower: _Eco(seeds: 7000, fert: 8000, pest: 3500, water: 3000, fuel: 9000, labor: 5000, yieldKgHa: 2400, price: 38,
      buyer: 'на маслозавод'),
  CropType.tomato: _Eco(seeds: 30000, fert: 20000, pest: 12000, water: 8000, fuel: 6000, labor: 60000, yieldKgHa: 30000, price: 30,
      buyer: 'на Ошском базаре', fertNote: 'Комплексное удобрение NPK', treatNote: 'Против фитофторы'),
  CropType.cabbage: _Eco(seeds: 15000, fert: 15000, pest: 8000, water: 8000, fuel: 6000, labor: 40000, yieldKgHa: 45000, price: 12,
      buyer: 'на Ошском базаре', treatNote: 'Против капустной белянки'),
  CropType.onion: _Eco(seeds: 25000, fert: 15000, pest: 8000, water: 7000, fuel: 7000, labor: 45000, yieldKgHa: 35000, price: 16,
      buyer: 'перекупщикам', treatNote: 'Против луковой мухи'),
  CropType.sugarBeet: _Eco(seeds: 12000, fert: 16000, pest: 6000, water: 7000, fuel: 14000, labor: 12000, yieldKgHa: 42000, price: 4.5,
      buyer: 'на сахарный завод'),
  CropType.alfalfa: _Eco(seeds: 14000, fert: 5000, pest: 0, water: 2500, fuel: 3500, labor: 3000, yieldKgHa: 3000, price: 9,
      buyer: 'животноводам на сено', fertNote: 'Суперфосфат под посев'),
};
