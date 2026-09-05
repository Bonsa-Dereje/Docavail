import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'patients.dart';

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
  final String id;
  final String name;
  final String ageGender;
  final String waitLabel;
  final String detailLabel;
  final String detailText;
  final _PatientTag tag;
  final _PatientStatus status;

  const _QueuePatient({
    required this.id,
    required this.name,
    required this.ageGender,
    required this.waitLabel,
    required this.detailLabel,
    required this.detailText,
    required this.tag,
    required this.status,
  });

  /// Builds a queue row from one entry of GET /api/queue_fetch's
  /// `patients` array. See that endpoint's file header for the schema
  /// caveats behind the choices below (no real status or tag columns
  /// exist yet).
  factory _QueuePatient.fromJson(Map<String, dynamic> json) {
    final fullName = json['full_name'] as String? ?? 'Unknown Patient';
    final age = json['age'] as int?;
    final gender = json['gender'] as String?;
    final chiefComplaint = json['chief_complaint'] as String?;
    final triageLevel = json['triage_level'] as String?;
    final triagedAt = json['triaged_at'] != null
        ? DateTime.tryParse(json['triaged_at'] as String)
        : null;

    return _QueuePatient(
      id: json['id'] as String,
      name: fullName,
      ageGender: [
        if (age != null) '$age y/o',
        if (gender != null && gender.isNotEmpty) gender,
      ].join(' • '),
      waitLabel: _waitLabelFor(triagedAt),
      detailLabel: 'CHIEF COMPLAINT',
      detailText: chiefComplaint?.isNotEmpty == true
          ? chiefComplaint!
          : 'No chief complaint recorded.',
      tag: _tagFromTriageLevel(triageLevel),
      // The endpoint only ever returns today's triaged patients — there's
      // no column yet to tell "waiting" apart from "in consult" or
      // "discharged", so everything comes back as waiting for now.
      status: _PatientStatus.waiting,
    );
  }

  /// Heuristic mapping from a clinical `triage_level` string to this
  /// screen's four UI tags. Adjust the matches below to whatever values
  /// your triage_level column actually uses — this is a best guess, not
  /// derived from any real convention in the schema.
  static _PatientTag _tagFromTriageLevel(String? triageLevel) {
    final level = triageLevel?.toLowerCase() ?? '';
    if (level.contains('urgent') || level == '1' || level == '2') {
      return _PatientTag.urgent;
    }
    if (level.contains('new')) return _PatientTag.newPatient;
    if (level.contains('follow')) return _PatientTag.followUp;
    return _PatientTag.routine;
  }

  static String _waitLabelFor(DateTime? triagedAt) {
    if (triagedAt == null) return 'Wait unknown';
    final minutes = DateTime.now().toUtc().difference(triagedAt.toUtc()).inMinutes;
    if (minutes < 1) return 'Just checked in';
    if (minutes < 60) return '${minutes}m wait';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m wait';
  }
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
    this.sessionToken,
    this.apiBaseUrl = _defaultApiBaseUrl,
  });

  /// The signed-in staff member's session token — same one profile.dart
  /// and patients.dart send as GET .../?token=.... Nullable so existing
  /// no-arg call sites still compile; shows a "not signed in" state when
  /// missing instead of fetching.
  final String? sessionToken;

  /// TODO: replace with your deployed Vercel URL (or read it from a
  /// shared config/env file if the app already has one). Keep this in
  /// sync with the same constant in patients.dart — consider centralizing
  /// both in one shared config file.
  static const String _defaultApiBaseUrl = 'https://YOUR-DEPLOYMENT.vercel.app';
  final String apiBaseUrl;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  int _selectedFilter = 0;
  Future<List<_QueuePatient>>? _queueFuture;

  @override
  void initState() {
    super.initState();
    _queueFuture = _fetchQueue();
  }

  @override
  void didUpdateWidget(covariant QueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing queue-fetch-relevant depends on sessionToken anymore (the
    // endpoint doesn't require it) — kept only for the didUpdateWidget
    // override shape in case that changes again later.
  }

  Future<List<_QueuePatient>> _fetchQueue() async {
    final uri = Uri.parse('${widget.apiBaseUrl}/api/queue_fetch');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      final body = _tryDecode(response.body);
      final message = body?['error'] as String? ?? 'Failed to load queue';
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final patientsJson = (decoded['patients'] as List<dynamic>?) ?? const [];
    return patientsJson
        .map((e) => _QueuePatient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    setState(() {
      _queueFuture = _fetchQueue();
    });
  }

  List<_QueuePatient> _filtered(List<_QueuePatient> patients) {
    switch (_selectedFilter) {
      case 1:
        return patients.where((p) => p.status == _PatientStatus.waiting).toList();
      case 2:
        return patients.where((p) => p.status == _PatientStatus.inConsult).toList();
      case 3:
        return patients.where((p) => p.status == _PatientStatus.discharged).toList();
      default:
        return patients;
    }
  }

  List<String> _filterLabels(List<_QueuePatient> patients) {
    final waiting = patients.where((p) => p.status == _PatientStatus.waiting).length;
    final inConsult = patients.where((p) => p.status == _PatientStatus.inConsult).length;
    final discharged = patients.where((p) => p.status == _PatientStatus.discharged).length;
    return [
      'All Patients',
      'Waiting ($waiting)',
      'In Consult ($inConsult)',
      'Discharged ($discharged)',
    ];
  }

  void _openPatientBrief(_QueuePatient patient) {
    // Navigating directly rather than through AppShellScope.switchTab(1)
    // so the actual tapped patient's id travels with it — switchTab alone
    // has no way to carry that. If Patient Brief should stay a bottom-nav
    // tab (no back button, as patients.dart's top bar comment assumes),
    // wire this through your AppShell's shared state instead once you can
    // share app_shell.dart.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientBriefScreen(
          patientId: patient.id,
          sessionToken: widget.sessionToken,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _QueueColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: FutureBuilder<List<_QueuePatient>>(
                future: _queueFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoading();
                  }
                  if (snapshot.hasError) {
                    return _buildError(snapshot.error.toString());
                  }
                  return _buildQueueList(snapshot.data ?? const []);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _QueueColors.navy),
          SizedBox(height: 16),
          Text(
            'Loading queue',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _QueueColors.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: _QueueColors.urgentFg,
            ),
            const SizedBox(height: 12),
            const Text(
              'Couldn\'t load the queue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _QueueColors.heading,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _QueueColors.subtitle),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _QueueColors.navy,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(List<_QueuePatient> allPatients) {
    final filters = _filterLabels(allPatients);
    final patients = _filtered(allPatients);

    return Column(
      children: [
        _buildFilterRow(filters),
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
          const Text(
            'No patients in this list',
            style: TextStyle(
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

  Widget _buildFilterRow(List<String> filters) {
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
                    _buildCardActions(patient),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardActions(_QueuePatient patient) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => _openPatientBrief(patient),
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
}