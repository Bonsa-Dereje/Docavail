import 'package:flutter/material.dart';

import 'patients.dart';
import 'profile.dart';

/// Brand + status colors used across the Notifications screen.
class _NotificationColors {
  static const navy = Color(0xFF0D2B9E);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const background = Color(0xFFF4F5F8);
  static const chipFill = Color(0xFFE7E9F1);
  static const divider = Color(0xFFE3E5EC);

  static const urgentBg = Color(0xFFFCE4E4);
  static const urgentFg = Color(0xFFD3323C);
  static const urgentBar = Color(0xFFD3323C);

  static const admissionBg = Color(0xFF0D2B9E);
  static const admissionFg = Colors.white;
  static const admissionBar = Color(0xFF0D2B9E);

  static const labBg = Color(0xFFB6F1DE);
  static const labFg = Color(0xFF0E7A57);
  static const labBar = Color(0xFF16A673);

  static const systemBg = Color(0xFFE7E9F1);
  static const systemFg = Color(0xFF5B6172);
  static const systemBar = Color(0xFF9AA1B4);
}

enum _NotificationCategory { ping, system, updates }

class _NotificationItem {
  final String title;
  final String timeLabel;
  final String message;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final Color barColor;
  final _NotificationCategory category;
  final List<String>? actions;

  const _NotificationItem({
    required this.title,
    required this.timeLabel,
    required this.message,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.barColor,
    required this.category,
    this.actions,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;
  int _selectedNavIndex = 2;

  /// Tracks the chosen quick-reply per ping notification (index in list ->
  /// selected action index). Defaults to 0 ("On my way") to match design.
  final Map<int, int> _selectedResponses = {0: 0};

  final List<_NotificationItem> _notifications = const [
    _NotificationItem(
      title: 'Urgent Ping',
      timeLabel: 'Just now',
      message: 'Immediate assistance required in Exam Room A for patient prep.',
      icon: Icons.priority_high_rounded,
      iconBg: _NotificationColors.urgentBg,
      iconFg: _NotificationColors.urgentFg,
      barColor: _NotificationColors.urgentBar,
      category: _NotificationCategory.ping,
      actions: ['On my way', '5 min', 'Busy'],
    ),
    _NotificationItem(
      title: 'New Admission',
      timeLabel: '15 min ago',
      message: 'Patient Robert Chen has been added to your queue in Room 12.',
      icon: Icons.person_add_alt_1_rounded,
      iconBg: _NotificationColors.admissionBg,
      iconFg: _NotificationColors.admissionFg,
      barColor: _NotificationColors.admissionBar,
      category: _NotificationCategory.updates,
    ),
    _NotificationItem(
      title: 'Lab Results Ready',
      timeLabel: '1 hr ago',
      message:
          'Complete blood count panel for Sarah Jenkins is now available for review.',
      icon: Icons.science_outlined,
      iconBg: _NotificationColors.labBg,
      iconFg: _NotificationColors.labFg,
      barColor: _NotificationColors.labBar,
      category: _NotificationCategory.updates,
    ),
  ];

  List<MapEntry<int, _NotificationItem>> get _filteredNotifications {
    final indexed = _notifications.asMap().entries.toList();
    switch (_selectedFilter) {
      case 1:
        return indexed
            .where((e) => e.value.category == _NotificationCategory.ping)
            .toList();
      case 2:
        return indexed
            .where((e) => e.value.category == _NotificationCategory.system)
            .toList();
      case 3:
        return indexed
            .where((e) => e.value.category == _NotificationCategory.updates)
            .toList();
      default:
        return indexed;
    }
  }

  static const List<String> _filters = ['All', 'Ping', 'System', 'Updates'];

  @override
  Widget build(BuildContext context) {
    final notifications = _filteredNotifications;

    return Scaffold(
      backgroundColor: _NotificationColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 8),
            _buildFilterRow(),
            const SizedBox(height: 16),
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final entry = notifications[index];
                        return _buildNotificationCard(entry.key, entry.value);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: _NotificationColors.subtitle,
          ),
          const SizedBox(height: 12),
          const Text(
            'No notifications in this list',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _NotificationColors.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _NotificationColors.heading,
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: hook up "Mark all as read" — placeholder for now.
            },
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _NotificationColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bool selected = index == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: selected
                    ? _NotificationColors.navy
                    : _NotificationColors.chipFill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                _filters[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _NotificationColors.heading,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(int index, _NotificationItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: item.barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, color: item.iconFg, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _NotificationColors.heading,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.timeLabel,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: _NotificationColors.subtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: _NotificationColors.subtitle,
                      ),
                    ),
                    if (item.actions != null) ...[
                      const SizedBox(height: 14),
                      _buildQuickActions(index, item.actions!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(int index, List<String> actions) {
    final int selected = _selectedResponses[index] ?? -1;

    return Row(
      children: List.generate(actions.length, (i) {
        final bool isSelected = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i == actions.length - 1 ? 0 : 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedResponses[index] = i),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? _NotificationColors.navy
                    : _NotificationColors.chipFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actions[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _NotificationColors.heading,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomNav() {
    final items = <_NavItem>[
      const _NavItem(icon: Icons.grid_view_rounded, label: 'Queue'),
      const _NavItem(icon: Icons.person_outline_rounded, label: 'Patients'),
      const _NavItem(
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
      ),
      const _NavItem(icon: Icons.account_circle_outlined, label: 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _NotificationColors.divider)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final bool selected = index == _selectedNavIndex;
            final item = items[index];
            final Color color = selected
                ? _NotificationColors.navy
                : _NotificationColors.subtitle;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (item.label == 'Profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  } else if (item.label == 'Patients') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PatientBriefScreen(),
                      ),
                    );
                  } else {
                    setState(() => _selectedNavIndex = index);
                  }
                },
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
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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