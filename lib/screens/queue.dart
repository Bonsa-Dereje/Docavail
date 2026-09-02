import 'package:flutter/material.dart';

import 'patients.dart';
import 'profile.dart';

/// Brand + status colors used across the Queue screen.
class _QueueColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const background = Color(0xFFF4F5F8);
  static const cardFill = Color(0xFFF0F1F5);
  static const divider = Color(0xFFE3E5EC);

  static const urgentBg = Color(0xFFFCE4E4);
  static const urgentFg = Color(0xFFD3323C);
  static const urgentBar = Color(0xFFD3323C);

  static const newPatientBg = Color(0xFF0D2B9E);
  static const newPatientFg = Colors.white;
  static const newPatientBar = Color(0xFF0D2B9E);

  static const followUpBg = Color(0xFFB6F1DE);
  static const followUpFg = Color(0xFF0E7A57);
  static const followUpBar = Color(0xFF16A673);

  static const dischargedBg = Color(0xFFE7E9F1);
  static const dischargedFg = Color(0xFF5B6172);
  static const dischargedBar = Color(0xFF9AA1B4);
}

enum _PatientTag { urgent, newPatient, followUp, routine }

enum _PatientStatus { waiting, inConsult, discharged }

class _QueuePatient {
  final String name;
  final String ageGender;
  final String waitLabel;
  final String detailLabel;
  final String detailText;
  final _PatientTag tag;
  final _PatientStatus status;

  const _QueuePatient({
    required this.name,
    required this.ageGender,
    required this.waitLabel,
    required this.detailLabel,
    required this.detailText,
    required this.tag,
    required this.status,
  });
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  int _selectedFilter = 0;
  int _selectedNavIndex = 0;

  final List<_QueuePatient> _patients = const [
    _QueuePatient(
      name: 'James Whitfield',
      ageGender: '42 y/o • Male',
      waitLabel: '45m wait',
      detailLabel: 'CHIEF COMPLAINT',
      detailText:
          'Severe chest pain radiating to the left arm. Shortness of breath and profuse sweating…',
      tag: _PatientTag.urgent,
      status: _PatientStatus.waiting,
    ),
    _QueuePatient(
      name: 'Amara Osei',
      ageGender: '28 y/o • Female',
      waitLabel: '12m wait',
      detailLabel: 'CHIEF COMPLAINT',
      detailText:
          'First time visit. Experiencing chronic migraines for the past 3 weeks, light…',
      tag: _PatientTag.newPatient,
      status: _PatientStatus.waiting,
    ),
    _QueuePatient(
      name: 'Robert Klein',
      ageGender: '65 y/o • Male',
      waitLabel: '5m wait',
      detailLabel: 'VISIT REASON',
      detailText:
          'Post-operation checkup for knee arthroscopy. Checking mobility and range of motion…',
      tag: _PatientTag.followUp,
      status: _PatientStatus.waiting,
    ),
    _QueuePatient(
      name: 'Sarah Nakamura',
      ageGender: '34 y/o • Female',
      waitLabel: '20m wait',
      detailLabel: 'CHIEF COMPLAINT',
      detailText:
          'Recurring lower back pain after lifting. Requesting evaluation and imaging…',
      tag: _PatientTag.urgent,
      status: _PatientStatus.waiting,
    ),
    _QueuePatient(
      name: 'Michael Torres',
      ageGender: '51 y/o • Male',
      waitLabel: 'In room 3',
      detailLabel: 'VISIT REASON',
      detailText:
          'Annual physical exam and bloodwork review. Discussing cholesterol management…',
      tag: _PatientTag.routine,
      status: _PatientStatus.inConsult,
    ),
    _QueuePatient(
      name: 'Linda Park',
      ageGender: '39 y/o • Female',
      waitLabel: 'Discharged 10:12 AM',
      detailLabel: 'VISIT SUMMARY',
      detailText:
          'Treated for seasonal allergies. Prescribed antihistamine, follow up in 2 weeks…',
      tag: _PatientTag.routine,
      status: _PatientStatus.discharged,
    ),
    _QueuePatient(
      name: 'David Chen',
      ageGender: '19 y/o • Male',
      waitLabel: 'Discharged 9:40 AM',
      detailLabel: 'VISIT SUMMARY',
      detailText:
          'Sprained ankle from soccer practice. X-ray clear, fitted with a brace…',
      tag: _PatientTag.followUp,
      status: _PatientStatus.discharged,
    ),
    _QueuePatient(
      name: 'Grace Muthoni',
      ageGender: '71 y/o • Female',
      waitLabel: '8m wait',
      detailLabel: 'CHIEF COMPLAINT',
      detailText:
          'Dizziness and occasional blurred vision over the past week. History of hypertension…',
      tag: _PatientTag.newPatient,
      status: _PatientStatus.waiting,
    ),
  ];

  List<_QueuePatient> get _filteredPatients {
    switch (_selectedFilter) {
      case 1:
        return _patients
            .where((p) => p.status == _PatientStatus.waiting)
            .toList();
      case 2:
        return _patients
            .where((p) => p.status == _PatientStatus.inConsult)
            .toList();
      case 3:
        return _patients
            .where((p) => p.status == _PatientStatus.discharged)
            .toList();
      default:
        return _patients;
    }
  }

  List<String> get _filters {
    final waiting = _patients
        .where((p) => p.status == _PatientStatus.waiting)
        .length;
    final inConsult = _patients
        .where((p) => p.status == _PatientStatus.inConsult)
        .length;
    final discharged = _patients
        .where((p) => p.status == _PatientStatus.discharged)
        .length;
    return [
      'All Patients',
      'Waiting ($waiting)',
      'In Consult ($inConsult)',
      'Discharged ($discharged)',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final patients = _filteredPatients;

    return Scaffold(
      backgroundColor: _QueueColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            _buildFilterRow(),
            const SizedBox(height: 16),
            Expanded(
              child: patients.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: patients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildPatientCard(patients[index]),
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
            Icons.inbox_rounded,
            size: 40,
            color: _QueueColors.subtitle,
          ),
          const SizedBox(height: 12),
          Text(
            'No patients in this list',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _QueueColors.subtitle,
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
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF16A673),
              shape: BoxShape.circle,
            ),
          ),
          const Expanded(
            child: Text(
              'My Queue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _QueueColors.navy,
              ),
            ),
          ),
          const Icon(
            Icons.filter_list_rounded,
            color: _QueueColors.heading,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = _filters;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bool selected = index == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: selected ? _QueueColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? _QueueColors.navy : _QueueColors.divider,
                ),
              ),
              child: Text(
                filters[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _QueueColors.heading,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientCard(_QueuePatient patient) {
    late final Color barColor;
    late final Color badgeBg;
    late final Color badgeFg;
    late final String badgeText;

    switch (patient.tag) {
      case _PatientTag.urgent:
        barColor = _QueueColors.urgentBar;
        badgeBg = _QueueColors.urgentBg;
        badgeFg = _QueueColors.urgentFg;
        badgeText = 'URGENT';
        break;
      case _PatientTag.newPatient:
        barColor = _QueueColors.newPatientBar;
        badgeBg = _QueueColors.newPatientBg;
        badgeFg = _QueueColors.newPatientFg;
        badgeText = 'NEW PATIENT';
        break;
      case _PatientTag.followUp:
        barColor = _QueueColors.followUpBar;
        badgeBg = _QueueColors.followUpBg;
        badgeFg = _QueueColors.followUpFg;
        badgeText = 'FOLLOW-UP';
        break;
      case _PatientTag.routine:
        barColor = _QueueColors.dischargedBar;
        badgeBg = _QueueColors.dischargedBg;
        badgeFg = _QueueColors.dischargedFg;
        badgeText = 'ROUTINE';
        break;
    }

    final bool isUrgent = patient.tag == _PatientTag.urgent;

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
                color: barColor,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _QueueColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                patient.ageGender,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _QueueColors.subtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBadge(badgeText, badgeBg, badgeFg),
                            const SizedBox(height: 8),
                            _buildWaitChip(patient.waitLabel, isUrgent),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _QueueColors.cardFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.detailLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: _QueueColors.subtitle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            patient.detailText,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: _QueueColors.heading,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildCardActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                // TODO: hook up "View Details" — placeholder for now.
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _QueueColors.heading,
                side: const BorderSide(color: _QueueColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                // TODO: hook up "Start Consult" — placeholder for now.
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _QueueColors.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Consult',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildWaitChip(String label, bool isUrgent) {
    final Color bg = isUrgent ? _QueueColors.urgentBg : Colors.white;
    final Color fg = isUrgent ? _QueueColors.urgentFg : _QueueColors.heading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: isUrgent ? null : Border.all(color: _QueueColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <_NavItem>[
      const _NavItem(icon: Icons.grid_view_rounded, label: 'Queue'),
      const _NavItem(icon: Icons.person_outline_rounded, label: 'Patients'),
      const _NavItem(
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        showDot: true,
      ),
      const _NavItem(icon: Icons.account_circle_outlined, label: 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _QueueColors.divider)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final bool selected = index == _selectedNavIndex;
            final item = items[index];
            final Color color = selected
                ? _QueueColors.navy
                : _QueueColors.subtitle;

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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(item.icon, color: color, size: 24),
                        if (item.showDot)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _QueueColors.urgentFg,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
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
  final bool showDot;

  const _NavItem({
    required this.icon,
    required this.label,
    this.showDot = false,
  });
}
