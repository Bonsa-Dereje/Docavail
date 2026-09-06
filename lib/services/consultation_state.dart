import 'package:flutter/foundation.dart';

/// Single source of truth for which of this doctor's assignments are
/// currently in an active consultation.
///
/// Both the Queue screen and the Patients screen derive their consultation
/// button/card state from this notifier instead of tracking their own local
/// copies, so a consultation started on either screen shows up everywhere
/// the instant the server confirms it.
///
/// The Queue screen feeds it: while it polls GET /api/patient_assign (which
/// it always is, since AppShell keeps every tab alive in an IndexedStack),
/// it publishes each assignment's `in_consultation` flag here. Every
/// listener — including the Patients screen — then rebuilds with the same
/// shared truth.
class ConsultationState extends ChangeNotifier {
  ConsultationState._();

  static final ConsultationState instance = ConsultationState._();

  /// assignment_id -> whether that assignment is currently in consultation.
  final Map<String, bool> _inConsultation = {};

  /// True when [assignmentId] is this doctor's active consultation.
  bool isInConsultation(String? assignmentId) {
    if (assignmentId == null) return false;
    return _inConsultation[assignmentId] == true;
  }

  /// True when we have polled the server at least once, so listeners can
  /// distinguish "not in consultation yet" from "we just haven't heard
  /// from the server".
  bool get hasData => _inConsultation.isNotEmpty;

  /// True when at least one of this doctor's assignments is currently in an
  /// active consultation. The Profile screen uses this to keep its
  /// availability mode ("Consulting") in sync with the Queue/Patients
  /// screens: whenever any patient is mid-consultation the doctor is
  /// effectively "Consulting", so the profile reflects that instead of an
  /// unrelated Hospital/Break/Leaving state.
  bool get hasActiveConsultation => _inConsultation.containsValue(true);

  /// assignment_id of the single consultation slot's current occupant, kept
  /// alongside [hasActiveConsultation] so a screen that wants to end the
  /// current session (e.g. before starting a different patient) knows which
  /// assignment to complete.
  String? _activeAssignmentId;

  /// Display name of the patient currently in consultation, for confirmation
  /// prompts ("End session with X?"). Published alongside the same poll that
  /// drives [_activeAssignmentId].
  String? _activePatientName;

  /// assignment_id of this doctor's active consultation, or null when no
  /// patient is mid-consultation.
  String? get activeAssignmentId => _activeAssignmentId;

  /// Display name of the patient currently in consultation, or null.
  String? get activePatientName => _activePatientName;

  /// Replaces the whole consultation table with the freshly-polled server
  /// truth, then notifies listeners if anything changed. [entries] is the
  /// doctor's full assignment list keyed by assignment_id -> in_consultation;
  /// [patientNames] maps the same keys to display names so prompts that end
  /// the current session can name the patient.
  void publish(Map<String, bool> entries, {Map<String, String>? patientNames}) {
    if (mapEquals(entries, _inConsultation)) return;
    _inConsultation
      ..clear()
      ..addAll(entries);
    _activeAssignmentId = null;
    _activePatientName = null;
    for (final entry in entries.entries) {
      if (entry.value == true) {
        _activeAssignmentId = entry.key;
        _activePatientName = patientNames?[entry.key];
        break;
      }
    }
    notifyListeners();
  }

  /// Marks [assignmentId] as in consultation optimistically (before the
  /// server round-trip) so the UI responds instantly, then lets the next
  /// poll confirm it. [name] lets callers seed the in-session patient's
  /// display name without waiting for the next poll.
  void markActive(String? assignmentId, {String? name}) {
    if (assignmentId == null) return;
    if (_inConsultation[assignmentId] == true) return;
    _inConsultation[assignmentId] = true;
    _activeAssignmentId = assignmentId;
    _activePatientName = name;
    notifyListeners();
  }

  /// Clears [assignmentId] from the consultation table (e.g. right after
  /// a successful complete) so the button flips back immediately instead of
  /// waiting for the next poll to drop the completed assignment.
  void markInactive(String? assignmentId) {
    if (assignmentId == null) return;
    if (_inConsultation.remove(assignmentId) == null) return;
    if (_activeAssignmentId == assignmentId) {
      _activeAssignmentId = null;
      _activePatientName = null;
    }
    notifyListeners();
  }
}
