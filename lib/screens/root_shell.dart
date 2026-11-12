import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'fields_screen.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Главный экран с нижней навигацией: Главная, Поля, Календарь, Финансы, Профиль.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  int _index = 0;

  /// Позволяет переключать вкладку из дочерних экранов (например, с главной).
  void goToTab(int i) => setState(() => _index = i);

  static RootShellState? of(BuildContext context) => context.findAncestorStateOfType<RootShellState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          FieldsScreen(),
          CalendarScreen(),
          FinanceScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.landscape_outlined), selectedIcon: Icon(Icons.landscape), label: 'Поля'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Календарь'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Финансы'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
