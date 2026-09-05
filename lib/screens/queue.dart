import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'app_shell.dart';
import 'patients.dart';
import 'selected_patient.dart';

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

/// Everything this screen needs from a single load: this doctor's entire
/// queue — every non-completed assignment from GET /api/patient_assign,
/// already scoped to the doctor identified by the session `token`. A
/// doctor can hold several assigned patients at once (the desktop admin
/// stacks them), so this is a list; at most one of them is in an active
/// consultation at any time.
class _QueueLoadResult {
  final List<_QueuePatient> patients;

  const _QueueLoadResult({required this.patients});
}

class _QueuePatient {
  /// public.patients.id of the assigned patient.
  final String id;

  /// patient_assignments.id — sent to the start_consult / complete calls.
  final String assignmentId;

  /// True when this assignment is the doctor's current consultation
  /// (status 'active'); false for queued-but-waiting ('assigned') ones.
  final bool inConsultation;

  final String name;
  final String ageGender;
  final String waitLabel;
  final String detailLabel;
  final String detailText;
  final _PatientTag tag;

  const _QueuePatient({
    required this.id,
    required this.assignmentId,
    required this.inConsultation,
    required this.name,
    required this.ageGender,
    required this.waitLabel,
    required this.detailLabel,
    required this.detailText,
    required this.tag,
  });

  /// Builds this doctor's queue card from one entry of GET
  /// /api/patient_assign's `my_assignments` array — field names differ
  /// from the old queue_fetch shape (`patient_id` not `id`,
  /// `assigned_at` not `triaged_at`), so this isn't a drop-in rename of
  /// the old `fromJson`.
  factory _QueuePatient.fromAssignment(Map<String, dynamic> json) {
    final fullName = json['full_name'] as String? ?? 'Unknown Patient';
    final age = json['age'] as int?;
    final gender = json['gender'] as String?;
    final chiefComplaint = json['chief_complaint'] as String?;
    final triageLevel = json['triage_level'] as String?;
    final assignedAt = json['assigned_at'] != null
        ? DateTime.tryParse(json['assigned_at'] as String)
        : null;

    return _QueuePatient(
      id: json['patient_id'] as String,
      assignmentId: json['assignment_id'] as String,
      inConsultation: json['in_consultation'] == true,
      name: fullName,
      ageGender: [
        if (age != null) '$age y/o',
        if (gender != null && gender.isNotEmpty) gender,
      ].join(' • '),
      waitLabel: _waitLabelFor(assignedAt),
      detailLabel: 'CHIEF COMPLAINT',
      detailText: chiefComplaint?.isNotEmpty == true
          ? chiefComplaint!
          : 'No chief complaint recorded.',
      tag: _tagFromTriageLevel(triageLevel),
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
  /// and patients.dart send as GET .../?token=.... When omitted (nullable
  /// so existing no-arg call sites, including AppShell's Queue tab, still
  /// compile), the screen resolves the token from secure storage itself —
  /// so a still-logged-in doctor gets their assignment without the caller
  /// having to thread the token through.
  final String? sessionToken;

  /// Deployed Vercel API base — same host the rest of the app uses
  /// (login.dart / profile.dart / auth_service.dart). Keep this in sync
  /// with the same constant in patients.dart — consider centralizing
  /// both in one shared config file.
  static const String _defaultApiBaseUrl = 'https://docavail-endpoints.vercel.app';
  final String apiBaseUrl;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen>
    with WidgetsBindingObserver {
  /// Same secure-storage key profile.dart reads/writes — lets this screen
  /// resolve the signed-in doctor's token by itself instead of relying on
  /// a caller to thread `sessionToken` through (AppShell constructs the
  /// Queue tab without one).
  static const _storage = FlutterSecureStorage();

  /// Current queue data, plus loading/error state, tracked as plain fields
  /// instead of a Future handed to a FutureBuilder. A FutureBuilder resets
  /// to its "waiting" state every time it's given a new Future instance —
  /// and the poll timer was doing exactly that once a second, so the whole
  /// list flashed back to the loading spinner on every tick even though
  /// the data hadn't really gone away. Keeping the result in state and
  /// only touching `_loading`/`_errorMessage` on the very first load (or a
  /// manual retry) means background polls just swap the list contents in
  /// place with no flicker.
  bool _loading = true;
  String? _errorMessage;
  _QueueLoadResult? _queueResult;

  /// Guards against overlapping poll requests: if a fetch triggered by one
  /// tick of the 1s timer is still waiting on the network when the next
  /// tick fires, skip that tick rather than firing a second request whose
  /// (possibly out-of-order) response could stomp on a newer one.
  bool _refreshInFlight = false;

  /// Assignment ids whose start_consult call (patient_assign.js
  /// {action:"start_consult"}) is in flight — those cards show "Starting…".
  /// A doctor can tap several cards quickly, so track each id separately.
  final Set<String> _startingConsultationIds = {};

  /// Assignment ids whose complete call (patient_assign.js
  /// {action:"complete"}) is in flight — those cards show "Ending…".
  final Set<String> _completingConsultationIds = {};

  /// True while POST .../patient_assign {action:"run"} is in flight —
  /// this is the stand-in "desktop admin" trigger, see patient_assign.js.
  bool _runningAssignment = false;

  /// How often the queue re-checks GET /api/patient_assign while mounted,
  /// so a patient assigned from the desktop admin tool appears here without
  /// the doctor needing to restart the app or switch tabs.
  static const _pollInterval = Duration(seconds: 1);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadQueue();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant QueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionToken != widget.sessionToken) {
      // A different (or newly available) session token changes whose
      // assignment "mine" means, so reload.
      _loadQueue();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Pauses the poll while the app is backgrounded — no desktop assignment
  /// is going to reach this doctor while they're not looking at the app, so
  /// there's no point keeping the request loop running.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    // Poll regardless of the widget-level token — _fetchQueue resolves the
    // stored token itself and no-ops cheaply when nobody is signed in.
    if (!mounted) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshAssignment());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Background re-check of this doctor's assignment (run by the poll
  /// timer) so an assignment made on the desktop admin tool shows up here
  /// automatically. Only swaps the result on success — a transient network
  /// error keeps the last-known assignment on screen and the next poll
  /// retries. Updates `_queueResult` directly (not `_loading`), so a
  /// successful poll just swaps the list in place instead of flashing the
  /// loading spinner every second.
  Future<void> _refreshAssignment() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final result = await _fetchQueue();
      if (!mounted) return;
      setState(() {
        _queueResult = result;
        _errorMessage = null;
      });
    } catch (_) {
      // Keep whatever was already showing; try again next cycle.
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Full (foreground) load: shows the spinner/error states. Used for the
  /// very first load, a token change, and manual retry — everywhere else
  /// (the poll timer, post-action refreshes) uses `_refreshAssignment` so
  /// existing data stays on screen while it re-checks.
  Future<void> _loadQueue() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await _fetchQueue();
      if (!mounted) return;
      setState(() {
        _queueResult = result;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorMessage = err.toString();
        _loading = false;
      });
    }
  }

  /// Resolves the signed-in doctor's session token: an explicit
  /// constructor override wins, otherwise fall back to the token saved by
  /// login (same secure-storage key profile.dart uses). Returns null when
  /// nobody is signed in.
  Future<String?> _resolveToken() async {
    final explicit = widget.sessionToken;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _storage.read(key: 'session_token');
  }

  /// Loads only this doctor's own assignment — GET /api/patient_assign
  /// already scopes `my_assignment` to the doctor identified by `token`,
  /// so there's no separate full-roster fetch to make or filter here.
  Future<_QueueLoadResult> _fetchQueue() async {
    // No signed-in doctor -> nothing to fetch; show the empty state.
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      return const _QueueLoadResult(patients: []);
    }

    final assignUri = Uri.parse(
      '${widget.apiBaseUrl}/api/patient_assign?token=${Uri.encodeQueryComponent(token)}',
    );

    final assignResponse = await http.get(assignUri).timeout(const Duration(seconds: 10));

    if (assignResponse.statusCode != 200) {
      final body = _tryDecode(assignResponse.body);
      final message = body?['error'] as String? ?? 'Failed to load your assignment';
      throw Exception(message);
    }

    final assignDecoded = jsonDecode(assignResponse.body) as Map<String, dynamic>;
    final mineList =
        (assignDecoded['my_assignments'] as List<dynamic>?) ?? const [];

    return _QueueLoadResult(
      patients: mineList
          .map((e) => _QueuePatient.fromAssignment(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    _loadQueue();
  }

  /// The stand-in "desktop admin" trigger — see patient_assign.js's
  /// {action:"run"} for why this lives on the mobile app for now. Grabs
  /// unassigned patients and free doctors and randomly pairs them, then
  /// reloads the queue so the app can pick up whatever landed on this
  /// doctor.
  Future<void> _runAutoAssign() async {
    if (_runningAssignment) return;
    setState(() => _runningAssignment = true);

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/patient_assign');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'run'}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = _tryDecode(response.body);
        throw Exception(body?['error'] as String? ?? 'Failed to assign patients');
      }

      if (!mounted) return;
      await _refreshAssignment();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-assign failed: $err')),
      );
    } finally {
      if (mounted) setState(() => _runningAssignment = false);
    }
  }

  /// Ends the doctor's consultation on one assignment (patient_assign.js
  /// {action:"complete"}), then reloads so the card drops out of the queue.
  Future<void> _completeAssignment(String assignmentId) async {
    if (_completingConsultationIds.contains(assignmentId)) return;
    final token = await _resolveToken();
    if (token == null || token.isEmpty) return;
    setState(() => _completingConsultationIds.add(assignmentId));

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/patient_assign');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'complete',
              'token': token,
              'assignment_id': assignmentId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = _tryDecode(response.body);
        throw Exception(body?['error'] as String? ?? 'Failed to end session');
      }

      if (!mounted) return;
      await _refreshAssignment();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t end session: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _completingConsultationIds.remove(assignmentId));
      }
    }
  }

  /// Moves one of the doctor's queued patients into the single
  /// consultation slot (patient_assign.js {action:"start_consult"}). The
  /// server demotes whatever else was in the slot first, so the card the
  /// doctor taps becomes the active one and the previous one drops back
  /// to waiting. Opens the Patient Brief optimistically, then reloads.
  Future<void> _startConsultation(_QueuePatient patient) async {
    if (_startingConsultationIds.contains(patient.assignmentId) ||
        _completingConsultationIds.contains(patient.assignmentId)) {
      return;
    }
    final token = await _resolveToken();
    if (token == null || token.isEmpty) return;
    setState(() => _startingConsultationIds.add(patient.assignmentId));
    _openPatientBrief(patient, autoStartConsultation: true);

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/patient_assign');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'start_consult',
              'token': token,
              'assignment_id': patient.assignmentId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final body = _tryDecode(response.body);
        throw Exception(
          body?['error'] as String? ?? 'Failed to start consultation',
        );
      }

      if (!mounted) return;
      await _refreshAssignment();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t start consultation: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _startingConsultationIds.remove(patient.assignmentId));
      }
    }
  }

  void _openPatientBrief(_QueuePatient patient, {bool autoStartConsultation = false}) {
    // Open the patient in the Patients tab (which keeps the bottom nav bar
    // visible) instead of pushing a bare route over the queue. The global
    // holds on to whichever patient was last opened; the Patients tab reads
    // it via AppShell on the next rebuild.
    SelectedPatient.select(
      patient.id,
      autoStartConsultation: autoStartConsultation,
    );

    final shell = AppShellScope.of(context);
    if (shell != null) {
      shell.switchTab(1);
      return;
    }

    // Fallback when this screen is used outside AppShell (no tab to switch
    // to) — keep the old push behavior so opening a patient still works.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientBriefScreen(
          patientId: patient.id,
          sessionToken: widget.sessionToken,
          apiBaseUrl: widget.apiBaseUrl,
          autoStartConsultation: autoStartConsultation,
        ),
      ),
    );
  }

  /// Routed from each queue card's consultation button. The card that is
  /// currently in consultation shows "End Session" (completes it); every
  /// other card shows "Start Consult" (moves it into the single
  /// consultation slot, demoting whatever was there).
  void _handleConsultButtonTap(_QueuePatient patient) {
    if (patient.inConsultation) {
      _completeAssignment(patient.assignmentId);
      return;
    }
    _startConsultation(patient);
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
              child: Builder(
                builder: (context) {
                  if (_loading && _queueResult == null) {
                    return _buildLoading();
                  }
                  if (_errorMessage != null && _queueResult == null) {
                    return _buildError(_errorMessage!);
                  }
                  final result = _queueResult;
                  if (result == null) return _buildEmptyState();
                  return _buildQueueList(result);
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

  Widget _buildQueueList(_QueueLoadResult result) {
    final patients = result.patients;

    if (patients.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildPatientCard(patients[index]),
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
            'No patient assigned to you right now',
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
              'My Patients',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _QueueColors.navy,
              ),
            ),
          ),
          // Stand-in for the desktop admin's "assign" action — see
          // patient_assign.js's {action:"run"}. Remove once the desktop
          // tool exists and does this instead.
          IconButton(
            tooltip: 'Auto-assign patients (temporary)',
            onPressed: _runningAssignment ? null : _runAutoAssign,
            icon: _runningAssignment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _QueueColors.navy,
                    ),
                  )
                : const Icon(
                    Icons.shuffle_rounded,
                    color: _QueueColors.heading,
                    size: 22,
                  ),
          ),
        ],
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
    // The card currently in consultation shows the red "End Session"
    // button; every other (waiting) card shows "Start Consult", which
    // moves it into that single consultation slot server-side.
    final bool inConsultation = patient.inConsultation;
    final bool starting = _startingConsultationIds.contains(patient.assignmentId);
    final bool completing = _completingConsultationIds.contains(patient.assignmentId);

    late final Color bg;
    late final String label;
    late final bool enabled;

    if (inConsultation) {
      bg = _QueueColors.urgentFg; // red
      label = completing ? 'Ending…' : 'End Session';
      enabled = !completing;
    } else if (starting) {
      bg = _QueueColors.followUpBar; // green
      label = 'Starting…';
      enabled = false;
    } else {
      bg = _QueueColors.navy;
      label = 'Start Consult';
      enabled = true;
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            // Plain card/"View Details" tap: just opens Patient Brief,
            // never auto-starts consultation there.
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
              onPressed: enabled
                  ? () => _handleConsultButtonTap(patient)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                disabledBackgroundColor: bg.withValues(alpha: 0.6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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