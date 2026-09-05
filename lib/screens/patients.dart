import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

/// Fetched shape of a single row from GET /api/patients_data_fetch.
/// Only the fields the Patient Brief screen actually renders are parsed
/// here — `medications` and the fuller `triage` fields (level, chief
/// complaint, notes) come back from the API too but aren't surfaced in
/// this screen yet.
class _PatientBriefData {
  final String fullName;
  final String? phoneNumber;
  final int? age;
  final String? gender;
  final List<_AllergyEntry> allergies;
  final DateTime? triagedAt;

  const _PatientBriefData({
    required this.fullName,
    this.phoneNumber,
    this.age,
    this.gender,
    required this.allergies,
    this.triagedAt,
  });

  factory _PatientBriefData.fromJson(Map<String, dynamic> json) {
    final patient = (json['patient'] as Map<String, dynamic>?) ?? const {};
    final allergiesJson = (json['allergies'] as List<dynamic>?) ?? const [];
    final triage = json['triage'] as Map<String, dynamic>?;

    return _PatientBriefData(
      fullName: patient['full_name'] as String? ?? 'Unknown Patient',
      phoneNumber: patient['phone_number'] as String?,
      age: patient['age'] as int?,
      gender: patient['gender'] as String?,
      allergies: allergiesJson
          .map((e) => _AllergyEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      triagedAt: triage != null && triage['triaged_at'] != null
          ? DateTime.tryParse(triage['triaged_at'] as String)
          : null,
    );
  }
}

class _AllergyEntry {
  final String allergen;
  final String? reaction;
  final String? severity;

  const _AllergyEntry({required this.allergen, this.reaction, this.severity});

  factory _AllergyEntry.fromJson(Map<String, dynamic> json) {
    return _AllergyEntry(
      allergen: json['allergen'] as String? ?? 'Unknown allergen',
      reaction: json['reaction'] as String?,
      severity: json['severity'] as String?,
    );
  }
}

/// Turns a timestamp into the "Last updated X mins ago" style label the
/// screen previously hardcoded.
String _timeAgoLabel(DateTime? when) {
  if (when == null) return 'No triage recorded yet';
  final diff = DateTime.now().toUtc().difference(when.toUtc());
  if (diff.inMinutes < 1) return 'Last updated just now';
  if (diff.inMinutes < 60) {
    return 'Last updated ${diff.inMinutes} mins ago';
  }
  if (diff.inHours < 24) {
    return 'Last updated ${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
  }
  return 'Last updated ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
}

/// Builds two-letter initials for the avatar chip, e.g. "Jane Doe" -> "JD".
String _initialsFor(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class PatientBriefScreen extends StatefulWidget {
  const PatientBriefScreen({
    super.key,
    this.patientId,
    this.sessionToken,
    this.apiBaseUrl = _defaultApiBaseUrl,
    this.onStartConsultation,
    this.onViewPatientHistory,
  });

  /// public.patients.id (uuid) for the patient this brief is for. Left
  /// nullable so existing call sites (e.g. a bottom-nav tab built before
  /// a patient is selected) still compile — when null, the screen shows
  /// a "no patient selected" state instead of fetching. Pass a real id
  /// once the caller knows which patient to show.
  final String? patientId;

  /// Not currently sent anywhere — patients_data_fetch.js has no auth
  /// check yet (see that file's header). Kept here so wiring a real
  /// session token back in later is a one-line change in
  /// _fetchPatientData rather than a constructor change.
  final String? sessionToken;

  /// TODO: replace with your deployed Vercel URL (or read it from a
  /// shared config/env file if the app already has one).
  static const String _defaultApiBaseUrl = 'https://YOUR-DEPLOYMENT.vercel.app';
  final String apiBaseUrl;

  final VoidCallback? onStartConsultation;
  final VoidCallback? onViewPatientHistory;

  @override
  State<PatientBriefScreen> createState() => _PatientBriefScreenState();
}

class _PatientBriefScreenState extends State<PatientBriefScreen> {
  Future<_PatientBriefData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) {
      _dataFuture = _fetchPatientData();
    }
  }

  @override
  void didUpdateWidget(covariant PatientBriefScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the caller re-pushes/rebuilds this screen with a different (or
    // newly-available) patient, kick off a fresh fetch for it.
    if (widget.patientId != oldWidget.patientId) {
      setState(() {
        _dataFuture = widget.patientId != null ? _fetchPatientData() : null;
      });
    }
  }

  Future<_PatientBriefData> _fetchPatientData() async {
    final uri = Uri.parse('${widget.apiBaseUrl}/api/patients_data_fetch').replace(
      queryParameters: {
        'patient_id': widget.patientId!,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final body = _tryDecode(response.body);
      final message = body?['error'] as String? ?? 'Failed to load patient data';
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _PatientBriefData.fromJson(decoded);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    if (widget.patientId == null) return;
    setState(() {
      _dataFuture = _fetchPatientData();
    });
  }

  // Vitals aren't in the current schema (no vitals table), so these stay
  // static placeholders until a table/column exists to fetch them from.
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
        child: _dataFuture == null
            ? _buildNoPatientSelected()
            : FutureBuilder<_PatientBriefData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoading();
                  }
                  if (snapshot.hasError) {
                    return _buildError(snapshot.error.toString());
                  }
                  return _buildLoaded(snapshot.data!);
                },
              ),
      ),
    );
  }

  Widget _buildNoPatientSelected() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    size: 36,
                    color: _PatientColors.subtitle,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No patient selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _PatientColors.heading,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Select a patient from the queue to view their brief.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _PatientColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _PatientColors.navy),
                SizedBox(height: 16),
                Text(
                  'Loading patient data',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _PatientColors.subtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: _PatientColors.allergyFg,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Couldn\'t load patient data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _PatientColors.heading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _PatientColors.subtitle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PatientColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoaded(_PatientBriefData data) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _buildPatientCard(data),
              if (data.allergies.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAllergyBanner(data.allergies),
              ],
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
                    _timeAgoLabel(data.triagedAt),
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
    );
  }

  Widget _buildTopBar() {
    // No back button here: as a bottom-nav tab (see AppShell) this screen
    // has no route to pop back to. If you also push PatientBriefScreen
    // directly (e.g. from a "View Details" action outside the shell), wrap
    // that pushed instance in its own AppBar with a back button instead.
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        'Patient Brief',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _PatientColors.heading,
        ),
      ),
    );
  }

  Widget _buildPatientCard(_PatientBriefData data) {
    // NOTE: no `mrn` column exists in public.patients, so the patient's
    // id is used in its place below — swap this out if you add one.
    final id = widget.patientId ?? '';
    final mrnLabel = id.length >= 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();
    final ageGenderParts = [
      if (data.age != null) '${data.age} Y',
      if (data.gender != null && data.gender!.isNotEmpty) data.gender!,
    ];

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
                            _initialsFor(data.fullName),
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
                                data.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _PatientColors.heading,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  'MRN: $mrnLabel',
                                  ...ageGenderParts,
                                ].join('  •  '),
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
                        _buildPatientHistoryButton(),
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

  Widget _buildPatientHistoryButton() {
    return Material(
      color: _PatientColors.waitChipBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onViewPatientHistory,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: _PatientColors.waitChipFg,
              ),
              const SizedBox(width: 6),
              const Text(
                'Patient History',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _PatientColors.waitChipFg,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: _PatientColors.waitChipFg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllergyBanner(List<_AllergyEntry> allergies) {
    final primary = allergies.first;
    final extraCount = allergies.length - 1;
    final detail = primary.reaction?.isNotEmpty == true
        ? primary.reaction!
        : 'No reaction details on file. Verify all medications prior to administration.';

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
                Text(
                  primary.severity?.isNotEmpty == true
                      ? '${primary.severity} Allergy'
                      : 'Allergy',
                  style: const TextStyle(
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
                        text: '${primary.allergen} — ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: detail),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: _PatientColors.allergyFg,
                  ),
                ),
                if (extraCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+$extraCount more allerg${extraCount == 1 ? 'y' : 'ies'} on file',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _PatientColors.allergyFg,
                    ),
                  ),
                ],
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
              Flexible(
                child: Text(
                  vital.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: _PatientColors.subtitle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(vital.icon, size: 18, color: vital.iconColor),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  vital.value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: vital.valueColor,
                  ),
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
            onPressed: widget.onStartConsultation,
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