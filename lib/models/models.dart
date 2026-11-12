import 'enums.dart';

export 'enums.dart';

DateTime _date(Object? v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Земельный участок.
class Field {
  Field({
    required this.id,
    required this.name,
    required this.areaHa,
    this.soil = SoilType.chernozem,
    this.status = FieldStatus.notProcessed,
    this.location = '',
    this.notes = '',
  });

  final String id;
  String name;
  double areaHa;
  SoilType soil;
  FieldStatus status;
  String location;
  String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'areaHa': areaHa,
        'soil': soil.name,
        'status': status.name,
        'location': location,
        'notes': notes,
      };

  factory Field.fromJson(Map<String, dynamic> j) => Field(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        areaHa: _num(j['areaHa']),
        soil: enumFromName(SoilType.values, j['soil'], SoilType.other),
        status: enumFromName(FieldStatus.values, j['status'], FieldStatus.notProcessed),
        location: j['location'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
      );
}

/// Посадка культуры на участке (модуль Crop Management).
class Planting {
  Planting({
    required this.id,
    required this.fieldId,
    required this.crop,
    required this.plantingDate,
    required this.expectedHarvestDate,
    this.variety = '',
    this.completed = false,
  });

  final String id;
  String fieldId;
  CropType crop;
  String variety;
  DateTime plantingDate;
  DateTime expectedHarvestDate;
  bool completed;

  /// Доля пройденного пути от посадки до сбора, 0..1.
  double progress(DateTime now) {
    final total = expectedHarvestDate.difference(plantingDate).inDays;
    if (total <= 0) return 1;
    return (now.difference(plantingDate).inDays / total).clamp(0, 1).toDouble();
  }

  int daysUntilHarvest(DateTime now) =>
      DateTime(expectedHarvestDate.year, expectedHarvestDate.month, expectedHarvestDate.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fieldId': fieldId,
        'crop': crop.name,
        'variety': variety,
        'plantingDate': plantingDate.toIso8601String(),
        'expectedHarvestDate': expectedHarvestDate.toIso8601String(),
        'completed': completed,
      };

  factory Planting.fromJson(Map<String, dynamic> j) => Planting(
        id: j['id'] as String,
        fieldId: j['fieldId'] as String? ?? '',
        crop: enumFromName(CropType.values, j['crop'], CropType.other),
        variety: j['variety'] as String? ?? '',
        plantingDate: _date(j['plantingDate']),
        expectedHarvestDate: _date(j['expectedHarvestDate']),
        completed: j['completed'] as bool? ?? false,
      );
}

/// Работа в календаре (полив, удобрение и т.д.).
class FarmTask {
  FarmTask({
    required this.id,
    required this.type,
    required this.date,
    this.fieldId,
    this.note = '',
    this.done = false,
  });

  final String id;
  TaskType type;
  DateTime date;
  String? fieldId;
  String note;
  bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        'fieldId': fieldId,
        'note': note,
        'done': done,
      };

  factory FarmTask.fromJson(Map<String, dynamic> j) => FarmTask(
        id: j['id'] as String,
        type: enumFromName(TaskType.values, j['type'], TaskType.other),
        date: _date(j['date']),
        fieldId: j['fieldId'] as String?,
        note: j['note'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

/// Доход или расход (сумма в сомах).
class FinanceEntry {
  FinanceEntry({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.fieldId,
    this.note = '',
  });

  final String id;
  FinanceCategory category;
  double amount;
  DateTime date;
  String? fieldId;
  String note;

  bool get isIncome => category.isIncome;

  /// Сумма со знаком: доход +, расход −.
  double get signedAmount => isIncome ? amount : -amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'fieldId': fieldId,
        'note': note,
      };

  factory FinanceEntry.fromJson(Map<String, dynamic> j) => FinanceEntry(
        id: j['id'] as String,
        category: enumFromName(FinanceCategory.values, j['category'], FinanceCategory.otherExpense),
        amount: _num(j['amount']),
        date: _date(j['date']),
        fieldId: j['fieldId'] as String?,
        note: j['note'] as String? ?? '',
      );
}

/// Запись о собранном урожае.
class Harvest {
  Harvest({
    required this.id,
    required this.fieldId,
    required this.crop,
    required this.date,
    required this.quantityKg,
    required this.areaHa,
    this.note = '',
  });

  final String id;
  String fieldId;
  CropType crop;
  DateTime date;
  double quantityKg;

  /// Площадь на момент сбора — чтобы урожайность не менялась при редактировании поля.
  double areaHa;
  String note;

  /// Урожайность, кг/га.
  double get yieldPerHa => areaHa > 0 ? quantityKg / areaHa : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fieldId': fieldId,
        'crop': crop.name,
        'date': date.toIso8601String(),
        'quantityKg': quantityKg,
        'areaHa': areaHa,
        'note': note,
      };

  factory Harvest.fromJson(Map<String, dynamic> j) => Harvest(
        id: j['id'] as String,
        fieldId: j['fieldId'] as String? ?? '',
        crop: enumFromName(CropType.values, j['crop'], CropType.other),
        date: _date(j['date']),
        quantityKg: _num(j['quantityKg']),
        areaHa: _num(j['areaHa']),
        note: j['note'] as String? ?? '',
      );
}

/// Профиль фермера.
class Profile {
  Profile({this.farmerName = '', this.farmName = '', this.city = 'Бишкек'});

  String farmerName;
  String farmName;

  /// Город для прогноза погоды (см. kCities).
  String city;

  Map<String, dynamic> toJson() => {'farmerName': farmerName, 'farmName': farmName, 'city': city};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        farmerName: j['farmerName'] as String? ?? '',
        farmName: j['farmName'] as String? ?? '',
        city: j['city'] as String? ?? 'Бишкек',
      );
}
