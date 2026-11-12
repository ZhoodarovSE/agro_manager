import 'package:agro_manager/app.dart';
import 'package:agro_manager/models/models.dart';
import 'package:agro_manager/services/weather_service.dart';
import 'package:agro_manager/state/app_state.dart';
import 'package:agro_manager/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Погода без интернета — чтобы тесты не ходили в сеть.
class _FakeWeather extends WeatherState {
  @override
  Future<void> load(String cityName, {bool force = false}) async {
    city = cityName;
    error = 'offline';
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Модели', () {
    test('урожайность считается на гектар', () {
      final h = Harvest(
          id: '1', fieldId: 'f', crop: CropType.potato, date: DateTime(2026), quantityKg: 50000, areaHa: 2.5);
      expect(h.yieldPerHa, 20000);
      expect(fmtYield(h.yieldPerHa), '200 ц/га');
    });

    test('расход и доход по категориям', () {
      final e = FinanceEntry(id: '1', category: FinanceCategory.fuel, amount: 100, date: DateTime(2026));
      expect(e.isIncome, isFalse);
      expect(e.signedAmount, -100);
    });

    test('JSON туда и обратно не теряет данные', () {
      final f = Field(id: 'a', name: 'Поле', areaHa: 1.5, soil: SoilType.loam, status: FieldStatus.growing);
      final back = Field.fromJson(f.toJson());
      expect(back.name, 'Поле');
      expect(back.soil, SoilType.loam);
      expect(back.status, FieldStatus.growing);
    });

    test('ввод с запятой', () {
      expect(parseNum('2,5'), 2.5);
      expect(parseNum('12 000'), 12000);
      expect(parseNum('abc'), isNull);
    });
  });

  group('AppState', () {
    test('новая посадка закрывает старую на том же поле', () {
      final s = AppState();
      final f = Field(id: 'f', name: 'Поле', areaHa: 1);
      s.saveField(f);
      s.savePlanting(Planting(
          id: 'p1', fieldId: 'f', crop: CropType.wheat, plantingDate: DateTime(2026), expectedHarvestDate: DateTime(2026, 6)));
      s.savePlanting(Planting(
          id: 'p2', fieldId: 'f', crop: CropType.corn, plantingDate: DateTime(2026, 7), expectedHarvestDate: DateTime(2026, 11)));
      expect(s.activePlantingFor('f')?.crop, CropType.corn);
      expect(s.plantings.firstWhere((p) => p.id == 'p1').completed, isTrue);
      expect(f.status, FieldStatus.sown);
    });

    test('удаление поля удаляет его посадки, но сохраняет финансы', () {
      final s = AppState()..loadDemoData();
      final field = s.fields.first;
      final finCount = s.finances.length;
      s.deleteField(field.id);
      expect(s.plantings.where((p) => p.fieldId == field.id), isEmpty);
      expect(s.harvests.where((h) => h.fieldId == field.id), isEmpty);
      expect(s.finances.length, finCount);
    });

    test('демо-данные содержат историю хозяйства с 2023 года', () {
      final s = AppState()..loadDemoData();
      final years = s.harvests.map((h) => h.date.year).toSet();
      expect(years, containsAll([2023, 2024, 2025]));
      expect(s.finances.any((e) => e.date.year == 2023), isTrue);
      expect(s.finances.every((e) => !e.date.isAfter(DateTime.now())), isTrue);
      expect(s.activePlantings, isNotEmpty);
      expect(s.upcomingTasks(), isNotEmpty);
      for (var y = 2023; y < DateTime.now().year; y++) {
        final list = s.finances.where((e) => e.date.year == y);
        expect(s.incomeOf(list), greaterThan(s.expenseOf(list)), reason: 'хозяйство прибыльно в $y году');
      }
    });

    test('данные сохраняются и загружаются', () async {
      final s = AppState()..loadDemoData();
      await Future<void>.delayed(Duration.zero);
      final s2 = AppState();
      await s2.load();
      expect(s2.fields.length, s.fields.length);
      expect(s2.profile.farmerName, s.profile.farmerName);
    });
  });

  test('предупреждение о заморозках', () {
    final data = WeatherData(
      current: const CurrentWeather(temperature: 3, humidity: 60, precipitation: 0, windSpeed: 2, code: 0),
      days: [DayForecast(date: DateTime(2026, 4, 1), tMax: 10, tMin: -3, precipitation: 0, precipProbability: 0, code: 0)],
      fetchedAt: DateTime.now(),
    );
    expect(data.alerts.first.title, 'Заморозки');
  });

  testWidgets('приложение запускается и переключает вкладки', (tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider<WeatherState>(create: (_) => _FakeWeather()),
      ],
      child: const AgroManagerApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Начните с добавления поля'), findsOneWidget);
    await tester.tap(find.text('Демо-данные'));
    await tester.pumpAndSettle();
    expect(find.text('Начните с добавления поля'), findsNothing);

    await tester.tap(find.text('Поля').last);
    await tester.pumpAndSettle();
    expect(find.text('Верхнее поле'), findsOneWidget);

    await tester.tap(find.text('Финансы').last);
    await tester.pumpAndSettle();
    expect(find.text('Прибыль'), findsOneWidget);
  });
}
