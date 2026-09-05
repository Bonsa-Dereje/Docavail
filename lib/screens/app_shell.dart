import 'package:flutter/material.dart';

import 'patients.dart';
import 'profile.dart';
import 'queue.dart';
import 'selected_patient.dart';

/// Shared navigation shell for the app's primary tabs.
///
/// This is the Flutter equivalent of a Svelte/Next.js "layout": one
/// [Scaffold] owns the bottom nav bar permanently, and an [IndexedStack]
/// swaps which tab's content is visible while keeping every tab's state
/// alive underneath. Individual screens (QueueScreen, PatientBriefScreen,
/// ProfileScreen) no longer build their own bottom nav — this widget is the
/// single source of truth for it.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  /// Which tab to show first (0 = Queue, 1 = Patients, 2 = Profile).
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex = widget.initialIndex;

  static const Color _navy = Color(0xFF0D2B9E);
  static const Color _subtitle = Color(0xFF7A8194);
  static const Color _divider = Color(0xFFE3E5EC);

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.grid_view_rounded, label: 'Queue'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Patients'),
    _NavItem(icon: Icons.account_circle_outlined, label: 'Profile'),
  ];

  void switchTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScope(
      switchTab: switchTab,
      selectedIndex: _selectedIndex,
      child: Scaffold(
        // IndexedStack keeps every tab's widget (and its state, e.g. scroll
        // position or filter selection) alive, only hiding the inactive ones
        // instead of rebuilding them from scratch on every tap.
        //
        // The Patients tab is built with the currently-selected patient
        // (SelectedPatient — set by the queue's "View Details"/"Start
        // Consult" buttons) so PatientBriefScreen.didUpdateWidget re-fetches
        // whenever a different patient is opened.
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            QueueScreen(),
            PatientBriefScreen(
              patientId: SelectedPatient.patientId,
              autoStartConsultation: SelectedPatient.autoStartConsultation,
            ),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _divider)),
        ),
        child: Row(
          children: List.generate(_navItems.length, (index) {
            final bool selected = index == _selectedIndex;
            final item = _navItems[index];
            final Color color = selected ? _navy : _subtitle;

            return Expanded(
              child: GestureDetector(
                onTap: () => switchTab(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: color, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

/// Lets any screen inside [AppShell] switch tabs without a Navigator push —
/// e.g. `AppShellScope.of(context)?.switchTab(1);` to jump to Patients.
/// This replaces the old pattern of each screen pushing a new route for
/// Queue/Patients/Profile.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.switchTab,
    required this.selectedIndex,
    required super.child,
  });

  final ValueChanged<int> switchTab;
  final int selectedIndex;

  static AppShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      selectedIndex != oldWidget.selectedIndex;
}