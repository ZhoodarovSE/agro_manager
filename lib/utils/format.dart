import 'package:intl/intl.dart';

final _date = DateFormat('d MMM y', 'ru');
final _shortDate = DateFormat('d MMM', 'ru');
final _weekday = DateFormat('EEE, d MMM', 'ru');
final _monthYear = DateFormat('LLLL y', 'ru');
final _number = NumberFormat.decimalPattern('ru');
final _decimal = NumberFormat('#,##0.##', 'ru');

String fmtDate(DateTime d) => _date.format(d);
String fmtShortDate(DateTime d) => _shortDate.format(d);
String fmtWeekday(DateTime d) => _weekday.format(d);
String fmtMonthYear(DateTime d) {
  final s = _monthYear.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

/// 12 500 сом
String fmtMoney(double v) => '${_number.format(v.round())} сом';

/// 2,5 га
String fmtHa(double v) => '${_decimal.format(v)} га';

/// 850 кг или 12,4 т
String fmtKg(double kg) =>
    kg >= 1000 ? '${_decimal.format(kg / 1000)} т' : '${_number.format(kg.round())} кг';

/// Урожайность в центнерах с гектара — привычная единица для фермеров.
String fmtYield(double kgPerHa) => '${_decimal.format(kgPerHa / 100)} ц/га';

/// Разбирает число, введённое с запятой или точкой.
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));

String daysWord(int n) {
  final a = n.abs() % 100;
  final b = a % 10;
  if (a > 10 && a < 20) return 'дней';
  if (b == 1) return 'день';
  if (b >= 2 && b <= 4) return 'дня';
  return 'дней';
}
