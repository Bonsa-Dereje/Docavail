import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colors — kept in sync with the rest of the Docavail palette.
class _C {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const fieldFill = Color(0xFFF0F1F5);
  static const fieldHint = Color(0xFF9AA1B2);
  static const divider = Color(0xFFE3E5EC);
  static const background = Color(0xFFF3F5FB);
  static const success = Color(0xFF1F9D55);
  static const red = Color(0xFFD3323C);
}

// ---------------------------------------------------------------------------
// Entry point — shown after a Triage Nurse account is created / logged in
// ---------------------------------------------------------------------------

class TriageNurseScreen extends StatefulWidget {
  const TriageNurseScreen({super.key});

  @override
  State<TriageNurseScreen> createState() => _TriageNurseScreenState();
}

class _TriageNurseScreenState extends State<TriageNurseScreen> {
  bool? _isExistingPatient; // null = not chosen yet

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/docavail.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text(
              'Triage Station',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _C.heading,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isExistingPatient == null
            ? _PatientTypeSelector(
                onSelected: (existing) =>
                    setState(() => _isExistingPatient = existing),
              )
            : _isExistingPatient!
                ? _ExistingPatientFlow(
                    onBack: () => setState(() => _isExistingPatient = null),
                  )
                : _NewPatientFlow(
                    onBack: () => setState(() => _isExistingPatient = null),
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 0 — choose Existing Patient vs New Patient
// ---------------------------------------------------------------------------

class _PatientTypeSelector extends StatelessWidget {
  const _PatientTypeSelector({required this.onSelected});

  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      // Push the buttons slightly above the vertical center.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BigChoiceButton(
              icon: Icons.person_search_rounded,
              label: 'Existing Patient',
              subtitle: 'Look up by phone number',
              onTap: () => onSelected(true),
            ),
            const SizedBox(height: 16),
            _BigChoiceButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'New Patient',
              subtitle: 'Register and triage',
              onTap: () => onSelected(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigChoiceButton extends StatelessWidget {
  const _BigChoiceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            border: Border.all(color: _C.divider),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _C.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _C.navy, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: _C.subtitle),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _C.subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Existing Patient flow — phone lookup + triage form
// ---------------------------------------------------------------------------

class _ExistingPatientFlow extends StatefulWidget {
  const _ExistingPatientFlow({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_ExistingPatientFlow> createState() => _ExistingPatientFlowState();
}

class _ExistingPatientFlowState extends State<_ExistingPatientFlow> {
  final _phoneController = TextEditingController();

  /// Simulated patient name after lookup (will be wired to endpoint later).
  String? _foundPatientName;
  bool _searched = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searched = true;
      // TODO: wire to backend — for now just show a placeholder
      final phone = _phoneController.text.trim();
      _foundPatientName = phone.isNotEmpty ? 'Patient name will appear here' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back row
        _BackBar(label: 'Existing Patient', onBack: widget.onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phone lookup card
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Patient Phone Number'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InputField(
                              controller: _phoneController,
                              hint: '+251 9XX XXX XXX',
                              icon: Icons.call_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _search,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _C.darkBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Search',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_searched) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _foundPatientName != null
                                ? _C.success.withValues(alpha: 0.08)
                                : _C.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _foundPatientName != null
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: _foundPatientName != null
                                    ? _C.success
                                    : _C.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _foundPatientName ??
                                      'No patient found with that number.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _foundPatientName != null
                                        ? _C.success
                                        : _C.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Only show triage form once a patient is found
                if (_searched && _foundPatientName != null) ...[
                  const SizedBox(height: 16),
                  const _TriageForm(isNewPatient: false),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// New Patient flow — registration + triage form
// ---------------------------------------------------------------------------

class _NewPatientFlow extends StatelessWidget {
  const _NewPatientFlow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BackBar(label: 'New Patient', onBack: onBack),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _TriageForm(isNewPatient: true),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Triage Form — shared by both flows
// ---------------------------------------------------------------------------

class _TriageForm extends StatefulWidget {
  const _TriageForm({required this.isNewPatient});

  final bool isNewPatient;

  @override
  State<_TriageForm> createState() => _TriageFormState();
}

class _TriageFormState extends State<_TriageForm> {
  // ── Patient info (new patient only) ────────────────────────────────────
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;

  // ── Chief Complaint ────────────────────────────────────────────────────
  final _chiefComplaintController = TextEditingController();

  // ── Vitals ─────────────────────────────────────────────────────────────
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _rrController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodGlucoseController = TextEditingController();

  // ── Triage level ───────────────────────────────────────────────────────
  String? _triageLevel;
  static const _triageLevels = [
    'Immediate (Red)',
    'Urgent (Orange)',
    'Less Urgent (Yellow)',
    'Non-Urgent (Green)',
    'Expectant (Black)',
  ];

  // ── Allergies ─────────────────────────────────────────────────────────
  final _allergiesController = TextEditingController();

  // ── Medications ───────────────────────────────────────────────────────
  final _medicationsController = TextEditingController();

  // ── Symptoms / Notes ──────────────────────────────────────────────────
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  // ── Consciousness / Pain ──────────────────────────────────────────────
  final _painScaleController = TextEditingController();
  String? _consciousnessLevel;
  static const _consciousnessLevels = ['Alert', 'Verbal', 'Pain', 'Unresponsive'];

  @override
  void dispose() {
    for (final c in [
      _fullNameController, _ageController, _phoneController,
      _chiefComplaintController, _tempController, _heartRateController,
      _bpSystolicController, _bpDiastolicController, _spo2Controller,
      _rrController, _weightController, _heightController,
      _bloodGlucoseController, _allergiesController, _medicationsController,
      _symptomsController, _notesController, _painScaleController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // TODO: wire to endpoint
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Triage information ready to submit.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Patient Info (new patient only) ─────────────────────────────
        if (widget.isNewPatient) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  icon: Icons.person_outline,
                  title: 'Patient Information',
                ),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Full Name',
                  child: _InputField(
                    controller: _fullNameController,
                    hint: 'e.g. Tesfaye Dagne',
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Age',
                        child: _InputField(
                          controller: _ageController,
                          hint: 'Years',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Gender',
                        child: _DropdownField(
                          value: _gender,
                          hint: 'Select',
                          icon: Icons.wc_rounded,
                          items: const ['Male', 'Female', 'Other'],
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Phone Number',
                  child: _InputField(
                    controller: _phoneController,
                    hint: '+251 9XX XXX XXX',
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Triage Level ────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.warning_amber_rounded,
                title: 'Triage Level',
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Priority Level',
                child: _DropdownField(
                  value: _triageLevel,
                  hint: 'Select triage level',
                  icon: Icons.flag_outlined,
                  items: _triageLevels,
                  onChanged: (v) => setState(() => _triageLevel = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Chief Complaint ─────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chief Complaint',
              ),
              const SizedBox(height: 14),
              _MultilineField(
                controller: _chiefComplaintController,
                hint: "Describe the patient's main complaint...",
                minLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Vitals ──────────────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.monitor_heart_outlined,
                title: 'Vital Signs',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Temperature (°C)',
                      child: _InputField(
                        controller: _tempController,
                        hint: '36.6',
                        icon: Icons.thermostat_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Heart Rate (bpm)',
                      child: _InputField(
                        controller: _heartRateController,
                        hint: '72',
                        icon: Icons.favorite_border_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Blood Pressure (mmHg)',
                child: Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _bpSystolicController,
                        hint: 'Systolic',
                        icon: Icons.compress_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _C.subtitle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InputField(
                        controller: _bpDiastolicController,
                        hint: 'Diastolic',
                        icon: Icons.expand_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'SpO₂ (%)',
                      child: _InputField(
                        controller: _spo2Controller,
                        hint: '98',
                        icon: Icons.air_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Resp. Rate (breaths/min)',
                      child: _InputField(
                        controller: _rrController,
                        hint: '16',
                        icon: Icons.wind_power_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Weight (kg)',
                      child: _InputField(
                        controller: _weightController,
                        hint: '70',
                        icon: Icons.scale_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Height (cm)',
                      child: _InputField(
                        controller: _heightController,
                        hint: '170',
                        icon: Icons.height_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Blood Glucose (mg/dL)',
                child: _InputField(
                  controller: _bloodGlucoseController,
                  hint: '90',
                  icon: Icons.water_drop_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Consciousness & Pain ─────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.psychology_outlined,
                title: 'Neurological Assessment',
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Level of Consciousness (AVPU)',
                child: _DropdownField(
                  value: _consciousnessLevel,
                  hint: 'Select level',
                  icon: Icons.visibility_outlined,
                  items: _consciousnessLevels,
                  onChanged: (v) => setState(() => _consciousnessLevel = v),
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Pain Score (0–10)',
                child: _InputField(
                  controller: _painScaleController,
                  hint: '0 = No pain, 10 = Worst pain',
                  icon: Icons.sentiment_very_dissatisfied_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Allergies ────────────────────────────────────────────────────
        _SectionWithPageButton(
          icon: Icons.warning_amber_outlined,
          title: 'Allergies',
          buttonLabel: 'Allergies Page',
          onButtonPressed: () {
            // TODO: navigate to detailed allergies page
          },
          child: _MultilineField(
            controller: _allergiesController,
            hint: 'e.g. Penicillin – rash, Peanuts – anaphylaxis',
            minLines: 2,
          ),
        ),
        const SizedBox(height: 16),

        // ── Medications ──────────────────────────────────────────────────
        _SectionWithPageButton(
          icon: Icons.medication_outlined,
          title: 'Current Medications',
          buttonLabel: 'Medications Page',
          onButtonPressed: () {
            // TODO: navigate to detailed medications page
          },
          child: _MultilineField(
            controller: _medicationsController,
            hint: 'e.g. Metformin 500 mg twice daily',
            minLines: 2,
          ),
        ),
        const SizedBox(height: 16),

        // ── Symptoms ─────────────────────────────────────────────────────
        _SectionWithPageButton(
          icon: Icons.sick_outlined,
          title: 'Presenting Symptoms',
          buttonLabel: 'Symptoms Page',
          onButtonPressed: () {
            // TODO: navigate to detailed symptoms page
          },
          child: _MultilineField(
            controller: _symptomsController,
            hint: 'Describe onset, duration, associated symptoms...',
            minLines: 3,
          ),
        ),
        const SizedBox(height: 16),

        // ── Additional Notes ─────────────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.notes_rounded,
                title: 'Additional Notes',
              ),
              const SizedBox(height: 14),
              _MultilineField(
                controller: _notesController,
                hint: 'Any other observations or instructions...',
                minLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Submit ───────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text(
              'Submit Triage Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.darkBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section card that includes a "-> Full Page" button (for big sections)
// ---------------------------------------------------------------------------

class _SectionWithPageButton extends StatelessWidget {
  const _SectionWithPageButton({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onButtonPressed,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String buttonLabel;
  final VoidCallback onButtonPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _C.navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _C.navy, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.heading,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.navy,
                  side: const BorderSide(color: _C.navy, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

class _BackBar extends StatelessWidget {
  const _BackBar({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _C.heading,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.heading,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _C.navy.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _C.navy, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.heading,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _C.heading,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _C.subtitle,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14, color: _C.heading),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.fieldHint, fontSize: 13.5),
        prefixIcon: Icon(icon, color: _C.fieldHint, size: 18),
        filled: true,
        fillColor: _C.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.navy, width: 1.5),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.fieldHint),
      style: const TextStyle(fontSize: 14, color: _C.heading),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.fieldHint, fontSize: 13.5),
        prefixIcon: Icon(icon, color: _C.fieldHint, size: 18),
        filled: true,
        fillColor: _C.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.navy, width: 1.5),
        ),
      ),
      hint: Text(hint, style: const TextStyle(color: _C.fieldHint, fontSize: 13.5)),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.controller,
    required this.hint,
    this.minLines = 2,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14, color: _C.heading),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.fieldHint, fontSize: 13.5),
        filled: true,
        fillColor: _C.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.navy, width: 1.5),
        ),
      ),
    );
  }
}
