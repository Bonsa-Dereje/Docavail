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

  /// Replaces the whole consultation table with the freshly-polled server
  /// truth, then notifies listeners if anything changed. [entries] is the
  /// doctor's full assignment list keyed by assignment_id -> in_consultation.
  void publish(Map<String, bool> entries) {
    if (mapEquals(entries, _inConsultation)) return;
    _inConsultation
      ..clear()
      ..addAll(entries);
    notifyListeners();
  }

  /// Marks [assignmentId] as in consultation optimistically (before the
  /// server round-trip) so the UI responds instantly, then lets the next
  /// poll confirm it.
  void markActive(String? assignmentId) {
    if (assignmentId == null) return;
    if (_inConsultation[assignmentId] == true) return;
    _inConsultation[assignmentId] = true;
    notifyListeners();
  }

  /// Clears [assignmentId] from the consultation table (e.g. right after
  /// a successful complete) so the button flips back immediately instead of
  /// waiting for the next poll to drop the completed assignment.
  void markInactive(String? assignmentId) {
    if (assignmentId == null) return;
    if (_inConsultation.remove(assignmentId) == null) return;
    notifyListeners();
  }
}
