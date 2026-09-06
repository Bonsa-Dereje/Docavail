import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/consultation_state.dart';
import 'selected_patient.dart';

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

/// One entry from GET /api/patient_assign's `my_assignments` array, pared
/// down to just what the end-of-consultation "next patient" modal shows.
/// Deliberately separate from queue.dart's own `_QueuePatient` (that class
/// is private to that file) rather than sharing it.
class _NextPatientPreview {
  final String patientId;
  final String assignmentId;
  final String name;
  final String ageGender;
  final String waitLabel;
  final String chiefComplaint;

  const _NextPatientPreview({
    required this.patientId,
    required this.assignmentId,
    required this.name,
    required this.ageGender,
    required this.waitLabel,
    required this.chiefComplaint,
  });

  factory _NextPatientPreview.fromAssignment(Map<String, dynamic> json) {
    final age = json['age'] as int?;
    final gender = json['gender'] as String?;
    final chiefComplaint = json['chief_complaint'] as String?;
    final assignedAt = json['assigned_at'] != null
        ? DateTime.tryParse(json['assigned_at'] as String)
        : null;

    return _NextPatientPreview(
      patientId: json['patient_id'] as String,
      assignmentId: json['assignment_id'] as String,
      name: json['full_name'] as String? ?? 'Unknown Patient',
      ageGender: [
        if (age != null) '$age y/o',
        if (gender != null && gender.isNotEmpty) gender,
      ].join(' • '),
      waitLabel: _waitLabelFor(assignedAt),
      chiefComplaint: chiefComplaint?.isNotEmpty == true
          ? chiefComplaint!
          : 'No chief complaint recorded.',
    );
  }

  static String _waitLabelFor(DateTime? assignedAt) {
    if (assignedAt == null) return 'Wait unknown';
    final minutes =
        DateTime.now().toUtc().difference(assignedAt.toUtc()).inMinutes;
    if (minutes < 1) return 'Just checked in';
    if (minutes < 60) return '${minutes}m wait';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m wait';
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
    this.assignmentId,
    this.sessionToken,
    this.apiBaseUrl = _defaultApiBaseUrl,
    this.onStartConsultation,
    this.onViewPatientHistory,
    this.autoStartConsultation = false,
  });

  /// public.patients.id (uuid) for the patient this brief is for. Left
  /// nullable so existing call sites (e.g. a bottom-nav tab built before
  /// a patient is selected) still compile — when null, the screen shows
  /// a "no patient selected" state instead of fetching. Pass a real id
  /// once the caller knows which patient to show.
  final String? patientId;

  /// patient_assignments.id for [patientId] on this doctor's queue — the
  /// same id queue.dart sends to patient_assign.js's start_consult/complete
  /// actions. Needed so this screen's own Start/End Consultation button can
  /// make that same call instead of only flipping local UI state. Left
  /// nullable for call sites that predate this (e.g. a bare push without an
  /// assignment on hand); when null the button falls back to local-only
  /// behavior and a warning is logged, since there's nothing to tell the
  /// server to update.
  final String? assignmentId;

  /// Not currently sent anywhere — patients_data_fetch.js has no auth
  /// check yet (see that file's header). Kept here so wiring a real
  /// session token back in later is a one-line change in
  /// _fetchPatientData rather than a constructor change.
  final String? sessionToken;

  /// Deployed Vercel API base — same host the rest of the app uses
  /// (login.dart / profile.dart / auth_service.dart).
  static const String _defaultApiBaseUrl = 'https://docavail-endpoints.vercel.app';
  final String apiBaseUrl;

  final VoidCallback? onStartConsultation;
  final VoidCallback? onViewPatientHistory;

  /// When true, the screen opens with consultation already treated as
  /// started (button shows "End Consultation" immediately) — set this
  /// when navigating here from the queue's "Start Consult" button, which
  /// already kicked off the consultation on the queue card itself.
  final bool autoStartConsultation;

  @override
  State<PatientBriefScreen> createState() => _PatientBriefScreenState();
}

class _PatientBriefScreenState extends State<PatientBriefScreen> {
  /// Same secure-storage key queue.dart and profile.dart use — lets this
  /// screen resolve the signed-in doctor's token itself when it needs to
  /// ask GET /api/patient_assign who's next in the queue.
  static const _storage = FlutterSecureStorage();

  Future<_PatientBriefData>? _dataFuture;

  /// True while the start_consult/complete POST below is in flight — the
  /// button shows "Starting…"/"Ending…" and ignores taps meanwhile, same
  /// pattern as queue.dart's _startingConsultationIds/_completingConsultationIds.
  bool _consultationActionInFlight = false;

  /// Local-only fallback for the (degenerate) case where this screen has no
  /// assignment_id to tell the server about — see [_toggleConsultation].
  /// Normally the shared [ConsultationState] is the single source of truth.
  bool _fallbackConsultationActive = false;

  /// Concrete patient id this screen last fetched for. Lets
  /// [_effectivePatientId] tell a "still the same patient" rebuild apart
  /// from a "different patient selected" one without refetching or
  /// resetting the consultation button on every tab bounce.
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    // Rebuild when the queue's server poll publishes consultation state —
    // a session started or ended on the Queue screen shows up here without
    // a manual refetch.
    ConsultationState.instance.addListener(_onConsultationChanged);
    _syncFromSource();
    if (widget.autoStartConsultation) {
      // Fire the callback once the first frame is up, same as if the
      // user had pressed the button here themselves.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStartConsultation?.call();
      });
    }
  }

  void _onConsultationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant PatientBriefScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the caller re-pushes/rebuilds this screen with a different (or
    // newly-available) patient, kick off a fresh fetch for it. The
    // AppShell tab rebuilds this widget with SelectedPatient.patientId on
    // every tab switch, so opening a new patient from the queue lands here.
    if (widget.patientId != oldWidget.patientId) {
      setState(_syncFromSource);
    }
  }

  /// Which patient to show: an explicit [PatientBriefScreen.patientId]
  /// wins (pushed routes), otherwise the globally selected patient (the
  /// Patients tab).
  String? _effectivePatientId() =>
      widget.patientId ?? SelectedPatient.patientId;

  /// Which patient_assignments.id backs the current patient: an explicit
  /// [PatientBriefScreen.assignmentId] wins, otherwise whatever the queue
  /// screen stashed globally when it opened this patient. Needed so the
  /// Start/End Consultation button here can hit the same
  /// start_consult/complete actions queue.dart's own buttons use.
  String? _effectiveAssignmentId() =>
      widget.assignmentId ?? SelectedPatient.assignmentId;

  @override
  void dispose() {
    ConsultationState.instance.removeListener(_onConsultationChanged);
    super.dispose();
  }

  /// Re-reads the source of truth ([_effectivePatientId]) and, when it
  /// points at a patient this screen hasn't loaded yet, fetches it and
  /// syncs the consultation button's start state.
  void _syncFromSource() {
    final id = _effectivePatientId();
    if (id == null) {
      _loadedPatientId = null;
      _dataFuture = null;
      return;
    }
    if (id == _loadedPatientId) return;
    _loadedPatientId = id;
    _dataFuture = _fetchPatientData(id);
  }

  /// Whether the consultation button should read as active for the current
  /// patient. With an assignment id this is the shared [ConsultationState]
  /// (fed by the queue's server poll, so both screens always agree); with
  /// none it falls back to the local-only flag.
  bool get _isConsultationActive {
    final assignmentId = _effectiveAssignmentId();
    if (assignmentId != null) {
      return ConsultationState.instance.isInConsultation(assignmentId);
    }
    return _fallbackConsultationActive;
  }

  Future<void> _toggleConsultation() async {
    if (_consultationActionInFlight) return;
    final assignmentId = _effectiveAssignmentId();
    final targetActive = !_isConsultationActive;

    final token = await _resolveToken();

    if (assignmentId == null || token == null || token.isEmpty) {
      // Nothing to tell the server (e.g. this screen was opened without
      // going through the queue). Fall back to the old local-only toggle
      // so the button still works, but note that the queue screen won't
      // reflect this — there's no assignment_id to call start_consult /
      // complete with.
      debugPrint(
        'PatientBriefScreen: no assignmentId/token available, '
        'toggling consultation locally only — the queue will not update.',
      );
      setState(() => _fallbackConsultationActive = targetActive);
      if (targetActive) {
        ConsultationState.instance.markActive(assignmentId);
        widget.onStartConsultation?.call();
      } else {
        _promptNextPatient();
      }
      return;
    }

    setState(() => _consultationActionInFlight = true);
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/patient_assign');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': targetActive ? 'start_consult' : 'complete',
              'token': token,
              'assignment_id': assignmentId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = _tryDecode(response.body);
        throw Exception(
          body?['error'] as String? ??
              (targetActive
                  ? 'Failed to start consultation'
                  : 'Failed to end consultation'),
        );
      }

      if (!mounted) return;
      if (targetActive) {
        // Mark active optimistically — the queue's poll will confirm it.
        ConsultationState.instance.markActive(assignmentId);
        widget.onStartConsultation?.call();
      } else {
        // End success: flip the button immediately, then prompt who's next.
        // The queue poll drops the completed assignment entirely.
        ConsultationState.instance.markInactive(assignmentId);
        await _promptNextPatient();
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$err')),
      );
    } finally {
      if (mounted) setState(() => _consultationActionInFlight = false);
    }
  }

  /// Resolves the signed-in doctor's session token: an explicit
  /// [PatientBriefScreen.sessionToken] wins, otherwise the token login
  /// saved to secure storage (same key queue.dart and profile.dart use).
  Future<String?> _resolveToken() async {
    final explicit = widget.sessionToken;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _storage.read(key: 'session_token');
  }

  /// Looks up this doctor's queue and returns the first waiting (not
  /// currently in consultation) assignment other than [excludePatientId],
  /// or null if there isn't one or the lookup fails.
  Future<_NextPatientPreview?> _fetchNextWaitingPatient(
    String excludePatientId,
  ) async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) return null;

    final uri = Uri.parse('${widget.apiBaseUrl}/api/patient_assign').replace(
      queryParameters: {'token': token},
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final mine = (decoded['my_assignments'] as List<dynamic>?) ?? const [];

      for (final entry in mine) {
        final json = entry as Map<String, dynamic>;
        if (json['in_consultation'] == true) continue;
        final patientId = json['patient_id'] as String?;
        if (patientId == null || patientId == excludePatientId) continue;
        return _NextPatientPreview.fromAssignment(json);
      }
    } catch (_) {
      // Silent — no next-patient prompt is better than crashing the
      // "end consultation" action over a flaky network call.
    }
    return null;
  }

  /// Shows the blurred "who's next" modal immediately — before the network
  /// call even starts — with a loading state, then swaps in the patient
  /// card (or an empty state) once GET /api/patient_assign resolves. The
  /// showDialog call isn't awaited on the fetch, so the modal appears the
  /// instant "End Consultation" is tapped instead of the doctor staring at
  /// nothing while it loads.
  Future<void> _promptNextPatient() async {
    final currentId = _effectivePatientId();
    if (currentId == null) return;

    final future = _fetchNextWaitingPatient(currentId);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withValues(alpha: 0.25),
            alignment: Alignment.center,
            child: _NextPatientModal(
              future: future,
              onOpenDetails: _openPatientDetails,
            ),
          ),
        );
      },
    );
  }

  /// Switches this screen over to [patientId] — same globally-selected-
  /// patient mechanism the queue screen uses, so it opens right here
  /// instead of navigating anywhere. Just opens the brief; doesn't touch
  /// consultation state. [assignmentId] (when known, e.g. from the next-
  /// patient lookup) is forwarded to [SelectedPatient] so a consultation
  /// started from this screen can actually drive the shared
  /// [ConsultationState] — and therefore the matching card on the Queue
  /// tab — instead of degrading to a local-only toggle.
  void _openPatientDetails(String patientId, {String? assignmentId}) {
    SelectedPatient.select(
      patientId,
      assignmentId: assignmentId,
      autoStartConsultation: false,
    );
    setState(_syncFromSource);
  }

  Future<_PatientBriefData> _fetchPatientData(String patientId) async {
    final uri = Uri.parse('${widget.apiBaseUrl}/api/patients_data_fetch').replace(
      queryParameters: {
        'patient_id': patientId,
      },
    );

    final response = await http
      .get(uri)
      .timeout(const Duration(seconds: 10));

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
    final id = _effectivePatientId();
    if (id == null) return;
    setState(() {
      _dataFuture = _fetchPatientData(id);
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
    final id = _effectivePatientId() ?? '';
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
    final bool active = _isConsultationActive;
    final bool busy = _consultationActionInFlight;
    final String label = busy
        ? (active ? 'Ending…' : 'Starting…')
        : (active ? 'End Consultation' : 'Start Consultation');
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: busy ? null : _toggleConsultation,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  active ? _PatientColors.allergyIconBg : _PatientColors.navy,
              disabledBackgroundColor:
                  (active ? _PatientColors.allergyIconBg : _PatientColors.navy)
                      .withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active
                      ? Icons.stop_circle_outlined
                      : Icons.medical_services_outlined,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
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

/// Wraps the "who's next" fetch and swaps between a loading card, an empty
/// state (nobody else waiting), and the loaded [_NextPatientCard] as
/// [future] resolves — all inside the same blurred backdrop so nothing
/// pops in or out of the dialog itself.
class _NextPatientModal extends StatelessWidget {
  const _NextPatientModal({
    required this.future,
    required this.onOpenDetails,
  });

  final Future<_NextPatientPreview?> future;
  final void Function(String patientId, {String? assignmentId}) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NextPatientPreview?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _NextPatientLoadingCard();
        }
        final next = snapshot.data;
        if (next == null) {
          return _NextPatientEmptyCard(
            onClose: () => Navigator.of(context).pop(),
          );
        }
        return _NextPatientCard(
          patient: next,
          onOpenDetails: () {
            Navigator.of(context).pop();
            onOpenDetails(next.patientId, assignmentId: next.assignmentId);
          },
        );
      },
    );
  }
}

/// Shown the instant "End Consultation" is tapped, while GET
/// /api/patient_assign is still in flight.
class _NextPatientLoadingCard extends StatelessWidget {
  const _NextPatientLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _PatientColors.navy),
              SizedBox(height: 16),
              Text(
                'Loading next patient…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _PatientColors.heading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the lookup succeeds but nobody else is waiting.
class _NextPatientEmptyCard extends StatelessWidget {
  const _NextPatientEmptyCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_rounded,
                size: 32,
                color: _PatientColors.subtitle,
              ),
              const SizedBox(height: 12),
              const Text(
                'No one else waiting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _PatientColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your queue is clear for now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: _PatientColors.subtitle),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _PatientColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "who's next" card shown once the lookup finishes and someone is
/// waiting: name, wait time, chief complaint, and a single "Open Details"
/// action that opens that patient right here on the Patients screen.
class _NextPatientCard extends StatelessWidget {
  const _NextPatientCard({
    required this.patient,
    required this.onOpenDetails,
  });

  final _NextPatientPreview patient;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UP NEXT IN QUEUE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: _PatientColors.subtitle,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _PatientColors.navy,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initialsFor(patient.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _PatientColors.heading,
                          ),
                        ),
                        if (patient.ageGender.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            patient.ageGender,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: _PatientColors.subtitle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _PatientColors.waitChipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: _PatientColors.waitChipFg,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.waitLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _PatientColors.waitChipFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _PatientColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHIEF COMPLAINT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: _PatientColors.subtitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.chiefComplaint,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: _PatientColors.heading,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onOpenDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _PatientColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Open Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}