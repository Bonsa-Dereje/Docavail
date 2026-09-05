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

  /// Mirrors [PatientBriefScreen.autoStartConsultation]: when a
  /// consultation was already kicked off on the queue card, the brief
  /// should open showing "End Consultation".
  static bool autoStartConsultation = false;

  /// Overwrites the currently open patient with [id]. The previous
  /// patient (if any) is lost — only one is ever held.
  static void select(String id, {bool autoStartConsultation = false}) {
    patientId = id;
    SelectedPatient.autoStartConsultation = autoStartConsultation;
  }
}