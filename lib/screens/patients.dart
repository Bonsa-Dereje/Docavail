import 'package:flutter/material.dart';

/// Brand + status colors used across the Patient Brief screen.
class _PatientColors {
  static const navy = Color(0xFF0D2B9E);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const background = Color(0xFFF4F5F8);
  static const cardBorder = Color(0xFFE3E5EC);
  static const divider = Color(0xFFE3E5EC);

  static const urgentBar = Color(0xFFD3323C);

  static const waitChipBg = Color(0xFFEFE9DA);
  static const waitChipFg = Color(0xFF7A6A3D);

  static const urgentChipBg = Color(0xFFFCE9E9);
  static const urgentChipFg = Color(0xFFD3323C);
  static const urgentChipBorder = Color(0xFFF6C9C9);

  static const allergyBg = Color(0xFFFCD9D9);
  static const allergyFg = Color(0xFFB01F28);
  static const allergyIconBg = Color(0xFFD3323C);

  static const vitalBorder = Color(0xFFE3E5EC);
  static const heartRateFg = Color(0xFFD3323C);
  static const temperatureFg = Color(0xFF8A6D1D);
  static const bloodPressureFg = _PatientColors.heading;
  static const spo2Fg = Color(0xFF0D2B9E);
}

class _VitalStat {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color valueColor;
  final Color iconColor;

  const _VitalStat({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.valueColor,
    required this.iconColor,
  });
}

class PatientBriefScreen extends StatelessWidget {
  const PatientBriefScreen({
    super.key,
    this.patientLabel = 'P1',
    this.patientName = 'Patient 001',
    this.mrn = '987654321',
    this.age = 45,
    this.gender = 'M',
    this.waitLabel = '45m Wait',
    this.triageLevel = 'Level 2 - Urgent',
    this.allergyName = 'Penicillin',
    this.allergyDetail =
        'History of severe anaphylaxis. Verify all medications prior to administration.',
    this.lastUpdatedLabel = 'Last updated 12 mins ago',
    this.onStartConsultation,
  });

  final String patientLabel;
  final String patientName;
  final String mrn;
  final int age;
  final String gender;
  final String waitLabel;
  final String triageLevel;
  final String allergyName;
  final String allergyDetail;
  final String lastUpdatedLabel;
  final VoidCallback? onStartConsultation;

  List<_VitalStat> get _vitals => const [
        _VitalStat(
          label: 'Heart Rate',
          value: '108',
          unit: 'bpm',
          icon: Icons.favorite_rounded,
          valueColor: _PatientColors.heartRateFg,
          iconColor: _PatientColors.heartRateFg,
        ),
        _VitalStat(
          label: 'Blood Pressure',
          value: '142/88',
          unit: 'mmHg',
          icon: Icons.monitor_heart_outlined,
          valueColor: _PatientColors.heading,
          iconColor: _PatientColors.heading,
        ),
        _VitalStat(
          label: 'Temperature',
          value: '38.4',
          unit: '°C',
          icon: Icons.thermostat_rounded,
          valueColor: _PatientColors.temperatureFg,
          iconColor: _PatientColors.temperatureFg,
        ),
        _VitalStat(
          label: 'SpO2',
          value: '96',
          unit: '%',
          icon: Icons.air_rounded,
          valueColor: _PatientColors.spo2Fg,
          iconColor: _PatientColors.spo2Fg,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PatientColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _buildPatientCard(),
                  const SizedBox(height: 16),
                  _buildAllergyBanner(),
                  const SizedBox(height: 28),
                  const Text(
                    'Triage Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _PatientColors.heading,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildVitalsGrid(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: _PatientColors.subtitle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lastUpdatedLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _PatientColors.subtitle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildStartConsultationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _PatientColors.heading),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            'Patient Brief',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _PatientColors.heading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PatientColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: _PatientColors.urgentBar,
                borderRadius: BorderRadius.only(
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _PatientColors.navy,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            patientLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _PatientColors.heading,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'MRN: $mrn  •  $age Y  •  $gender',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _PatientColors.subtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildWaitChip(),
                        _buildTriageChip(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _PatientColors.waitChipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 16,
            color: _PatientColors.waitChipFg,
          ),
          const SizedBox(width: 6),
          Text(
            waitLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _PatientColors.waitChipFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _PatientColors.urgentChipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PatientColors.urgentChipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_rounded,
            size: 16,
            color: _PatientColors.urgentChipFg,
          ),
          const SizedBox(width: 6),
          Text(
            triageLevel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _PatientColors.urgentChipFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PatientColors.allergyBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _PatientColors.allergyIconBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Severe Allergy',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _PatientColors.allergyFg,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$allergyName — ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: allergyDetail),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: _PatientColors.allergyFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.55,
      children: _vitals.map(_buildVitalCard).toList(),
    );
  }

  Widget _buildVitalCard(_VitalStat vital) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _PatientColors.vitalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vital.label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: _PatientColors.subtitle,
                ),
              ),
              Icon(vital.icon, size: 18, color: vital.iconColor),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                vital.value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: vital.valueColor,
                ),
              ),
              if (vital.unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  vital.unit!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _PatientColors.subtitle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartConsultationButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onStartConsultation,
            style: ElevatedButton.styleFrom(
              backgroundColor: _PatientColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_outlined, size: 20),
                SizedBox(width: 10),
                Text(
                  'Start Consultation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}