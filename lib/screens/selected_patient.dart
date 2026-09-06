/// Holds the single patient currently "open" in the app.
///
/// This is a plain global holder, not app state: only one patient is
/// ever stored, and opening a new patient overwrites the previous one.
/// The queue's "View Details" / "Start Consult" buttons write to it, the
/// Patients tab reads it (via [AppShell], which hands it to
/// [PatientBriefScreen]'s `patientId`), and anything else can consult
/// [patientId] directly.
class SelectedPatient {
  SelectedPatient._();

  /// public.patients.id of the currently open patient, or null before
  /// any patient has been opened this session.
  static String? patientId;

  /// public.patient_assignments.id backing the currently open patient,
  /// or null when the patient was opened without going through the
  /// queue (so there's no assignment to drive start_consult/complete
  /// calls with). Set alongside [patientId] by [select].
  static String? assignmentId;

  /// Mirrors [PatientBriefScreen.autoStartConsultation]: when a
  /// consultation was already kicked off on the queue card, the brief
  /// should open showing "End Consultation".
  static bool autoStartConsultation = false;

  /// Overwrites the currently open patient with [id]. The previous
  /// patient (if any) is lost — only one is ever held.
  static void select(
    String id, {
    String? assignmentId,
    bool autoStartConsultation = false,
  }) {
    patientId = id;
    SelectedPatient.assignmentId = assignmentId;
    SelectedPatient.autoStartConsultation = autoStartConsultation;
  }
}