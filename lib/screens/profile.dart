import 'package:flutter/material.dart';

/// Brand + status colors used across the Profile / Status Control screen.
class _ProfileColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const background = Color(0xFFF4F5F8);
  static const divider = Color(0xFFE3E5EC);
  static const onDutyGreen = Color(0xFF16A673);
}

enum _AvailabilityMode { hospital, consulting, onBreak, leaving }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _onDuty = true;
  _AvailabilityMode _mode = _AvailabilityMode.hospital;
  final String _lastUpdated = '08:42 AM';

  void _selectMode(_AvailabilityMode mode) {
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfileColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Control',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _ProfileColors.heading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage your current availability and location.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _ProfileColors.subtitle,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDoctorCard(),
                    const SizedBox(height: 20),
                    _buildAvailabilityGrid(),
                    const SizedBox(height: 24),
                    _buildLastUpdated(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: _ProfileColors.divider,
            child: Icon(Icons.person, color: _ProfileColors.subtitle),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My Queue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ProfileColors.navy,
              ),
            ),
          ),
          const Icon(
            Icons.filter_list_rounded,
            color: _ProfileColors.navy,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: _ProfileColors.divider,
                child: Icon(Icons.person,
                    color: _ProfileColors.subtitle, size: 28),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _onDuty
                        ? _ProfileColors.onDutyGreen
                        : _ProfileColors.subtitle,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. S. Jenkins',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ProfileColors.heading,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Attending Cardiologist',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ProfileColors.subtitle,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _onDuty ? 'On Duty' : 'Off Duty',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _onDuty
                      ? _ProfileColors.onDutyGreen
                      : _ProfileColors.subtitle,
                ),
              ),
              const SizedBox(height: 6),
              Switch(
                value: _onDuty,
                onChanged: (value) => setState(() => _onDuty = value),
                activeThumbColor: Colors.white,
                activeTrackColor: _ProfileColors.navy,
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                  (states) => states.contains(WidgetState.selected)
                      ? const Icon(Icons.check, color: _ProfileColors.navy)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: [
        _buildModeCard(
          mode: _AvailabilityMode.hospital,
          icon: Icons.local_hospital_outlined,
          label: 'Hospital',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.consulting,
          icon: Icons.medical_services_outlined,
          label: 'Consulting',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.onBreak,
          icon: Icons.free_breakfast_outlined,
          label: 'On Break',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.leaving,
          icon: Icons.directions_walk_rounded,
          label: 'Leaving',
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required _AvailabilityMode mode,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _mode == mode;
    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? _ProfileColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _ProfileColors.navy : _ProfileColors.divider,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? Colors.white : _ProfileColors.heading,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _ProfileColors.heading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded,
              size: 16, color: _ProfileColors.subtitle),
          const SizedBox(width: 6),
          Text(
            'Status updated at $_lastUpdated',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _ProfileColors.subtitle,
            ),
          ),
        ],
      ),
    );
  }

}