import 'package:flutter/material.dart';

/// Безопасно превращает строку из JSON обратно в значение enum.
T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum SoilType {
  chernozem('Чернозём'),
  serozem('Серозём'),
  chestnut('Каштановая'),
  loam('Суглинок'),
  sandyLoam('Супесь'),
  clay('Глинистая'),
  other('Другая');

  const SoilType(this.label);
  final String label;
}

enum FieldStatus {
  notProcessed('Не обработано', Colors.grey),
  plowed('Вспахано', Colors.brown),
  sown('Засеяно', Colors.lightGreen),
  growing('Вегетация', Colors.green),
  harvested('Урожай собран', Colors.orange),
  fallow('Под паром', Colors.blueGrey);

  const FieldStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum CropType {
  potato('Картофель', '🥔', 110),
  wheat('Пшеница', '🌾', 120),
  corn('Кукуруза', '🌽', 130),
  barley('Ячмень', '🌾', 100),
  beans('Фасоль', '🫘', 100),
  cotton('Хлопок', '☁️', 150),
  sugarBeet('Сахарная свёкла', '🍠', 160),
  sunflower('Подсолнечник', '🌻', 120),
  alfalfa('Люцерна', '🍀', 90),
  tomato('Томаты', '🍅', 110),
  onion('Лук', '🧅', 120),
  carrot('Морковь', '🥕', 100),
  cabbage('Капуста', '🥬', 110),
  rice('Рис', '🍚', 140),
  other('Другая культура', '🌱', 100);

  const CropType(this.label, this.emoji, this.growingDays);
  final String label;
  final String emoji;

  /// Примерный срок от посадки до сбора — для подсказки даты сбора.
  final int growingDays;
}

enum TaskType {
  watering('Полив', Icons.water_drop, Colors.blue),
  fertilizing('Удобрение', Icons.science, Colors.purple),
  planting('Посадка', Icons.grass, Colors.green),
  treatment('Обработка', Icons.pest_control, Colors.red),
  harvesting('Сбор урожая', Icons.agriculture, Colors.orange),
  other('Другое', Icons.event_note, Colors.blueGrey);

  const TaskType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum FinanceCategory {
  seeds('Семена', Icons.spa, false),
  fertilizer('Удобрения', Icons.science, false),
  fuel('Топливо', Icons.local_gas_station, false),
  pesticides('Средства защиты', Icons.pest_control, false),
  equipment('Техника и ремонт', Icons.build, false),
  labor('Оплата труда', Icons.people, false),
  water('Вода и полив', Icons.water_drop, false),
  otherExpense('Прочие расходы', Icons.more_horiz, false),
  sale('Продажа урожая', Icons.storefront, true),
  subsidy('Субсидии', Icons.account_balance, true),
  otherIncome('Прочие доходы', Icons.add_card, true);

  const FinanceCategory(this.label, this.icon, this.isIncome);
  final String label;
  final IconData icon;
  final bool isIncome;

  static List<FinanceCategory> forIncome(bool income) =>
      values.where((c) => c.isIncome == income).toList();
}
