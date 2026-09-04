import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login.dart' show IdLoginScreen;
import 'pin.dart';

/// Brand colors pulled from the Docavail mockup.
/// Kept in sync with the palette used in login_screen.dart / pin.dart.
class _DocavailColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const fieldFill = Color(0xFFF0F1F5);
  static const fieldHint = Color(0xFF9AA1B2);
  static const gradientTop = Color(0xFFEDEFFA);
  static const gradientBottom = Color(0xFFCFF3E6);
}

// TODO: point this at your deployed Vercel project. Keep this in sync
// with the constant of the same name in pin.dart / login.dart.
const String _apiBaseUrl = 'https://docavail-endpoints.vercel.app/api';

/// The roles a new user can register as.
enum DocavailRole {
  doctor('Dr.'),
  triageNurse('Triage Nurse'),
  reception('Reception');

  const DocavailRole(this.label);
  final String label;
}

/// Maps [DocavailRole] to/from the `user_role` Postgres enum values
/// ('doctor', 'triage_nurse', 'reception') used by userinfo.js.
extension DocavailRoleApi on DocavailRole {
  String get apiValue {
    switch (this) {
      case DocavailRole.doctor:
        return 'doctor';
      case DocavailRole.triageNurse:
        return 'triage_nurse';
      case DocavailRole.reception:
        return 'reception';
    }
  }
}

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key, this.phoneNumber});

  /// Phone number collected on the previous (login/OTP) screen, if any.
  /// Passed straight through to the existing-user check and, on to
  /// pin.dart / login.dart, so the user never has to retype it.
  final String? phoneNumber;

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  DocavailRole? _selectedRole;
  bool _isRegistering = false;

  Timer? _debounce;

  /// Cache of the last background existing-user check, keyed by
  /// "idNumber|phoneNumber" so `_finishSetup` can reuse it instead of
  /// firing another request the moment "Proceed" is tapped.
  Map<String, dynamic>? _existingCheckResult;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onIdChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _idController.removeListener(_onIdChanged);
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  String get _checkKey =>
      '${_idController.text.trim()}|${widget.phoneNumber ?? ''}';

  void _onIdChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _runBackgroundCheck);
  }

  /// Silently checks whether an account already exists for the ID (and
  /// phone number, if we have one) the user is typing — fired in the
  /// background while they're still filling out the rest of the form, so
  /// by the time they tap "Proceed" the result (and therefore the
  /// "Login Instead" card) is usually already available.
  Future<void> _runBackgroundCheck() async {
    final idNumber = _idController.text.trim();
    if (idNumber.isEmpty) return;

    final key = _checkKey;
    try {
      final result = await _fetchExistingCheck(idNumber);
      if (!mounted) return;
      // Only cache if the field hasn't changed again while we were waiting.
      if (key == _checkKey) {
        _existingCheckResult = {...result, 'key': key};
      }
    } catch (_) {
      // Non-fatal — this is just a background convenience check. If it
      // fails, `_finishSetup` will retry synchronously before proceeding.
    }
  }

  Future<Map<String, dynamic>> _fetchExistingCheck(String idNumber) async {
    final uri = Uri.parse('$_apiBaseUrl/userinfo').replace(queryParameters: {
      'id_number': idNumber,
      if (widget.phoneNumber != null) 'phone_number': widget.phoneNumber!,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Existing-user check failed (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Returns a fresh answer to "does this account already exist", reusing
  /// the cached background-check result when it's still up to date.
  Future<Map<String, dynamic>?> _resolveExistingCheck(String idNumber) async {
    final key = _checkKey;
    if (_existingCheckResult != null && _existingCheckResult!['key'] == key) {
      return _existingCheckResult;
    }
    try {
      final result = await _fetchExistingCheck(idNumber);
      _existingCheckResult = {...result, 'key': key};
      return _existingCheckResult;
    } catch (_) {
      // If the check can't be reached, let account creation proceed —
      // the 409 duplicate check on the backend is still a safety net.
      return null;
    }
  }

  Future<void> _finishSetup() async {
    final name = _nameController.text.trim();
    final idNumber = _idController.text.trim();

    if (name.isEmpty) {
      _showMessage('Enter your name first.');
      return;
    }
    if (idNumber.isEmpty) {
      _showMessage('Enter your ID number first.');
      return;
    }
    if (_selectedRole == null) {
      _showMessage('Select a role to continue.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = true);

    final existing = await _resolveExistingCheck(idNumber);

    if (!mounted) return;
    setState(() => _isRegistering = false);

    if (existing != null && existing['exists'] == true) {
      _showExistingUserDialog(idNumber);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PinScreen(
          fullName: name,
          role: _selectedRole!,
          idNumber: idNumber,
          phoneNumber: widget.phoneNumber,
          isLogin: false,
        ),
      ),
    );
  }

  void _showExistingUserDialog(String idNumber) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _DocavailColors.fieldFill,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: _DocavailColors.navy,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Account Already Exists',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _DocavailColors.heading,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "There's already an account with this ID. Log in instead.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: _DocavailColors.subtitle),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => IdLoginScreen(
                          idNumber: idNumber,
                          phoneNumber: widget.phoneNumber,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DocavailColors.darkBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Login Instead',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _DocavailColors.subtitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _DocavailColors.gradientTop,
              _DocavailColors.gradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildBrandHeader(),
                const SizedBox(height: 40),
                _buildUserInfoCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/icon/docavail.png',
          width: 96,
          height: 96,
        ),
        const SizedBox(height: 3),
        const Text(
          'Docavail',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _DocavailColors.heading,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Complete Your Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us a bit about yourself to finish setting up your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _DocavailColors.subtitle,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Full Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          _buildNameField(),
          const SizedBox(height: 20),
          const Text(
            'ID No.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          _buildIdField(),
          const SizedBox(height: 20),
          const Text(
            'Role',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          _buildRoleDropdown(),
          const SizedBox(height: 28),
          _buildProceedButton(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      enabled: !_isRegistering,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 15, color: _DocavailColors.heading),
      decoration: InputDecoration(
        hintText: 'e.g. Jordan Lee',
        hintStyle: const TextStyle(color: _DocavailColors.fieldHint),
        prefixIcon: const Icon(
          Icons.person_outline,
          color: _DocavailColors.fieldHint,
          size: 20,
        ),
        filled: true,
        fillColor: _DocavailColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _DocavailColors.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildIdField() {
    return TextField(
      controller: _idController,
      enabled: !_isRegistering,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontSize: 15, color: _DocavailColors.heading),
      decoration: InputDecoration(
        hintText: 'e.g. EMP-00231',
        hintStyle: const TextStyle(color: _DocavailColors.fieldHint),
        prefixIcon: const Icon(
          Icons.credit_card_outlined,
          color: _DocavailColors.fieldHint,
          size: 20,
        ),
        filled: true,
        fillColor: _DocavailColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _DocavailColors.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _DocavailColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButtonFormField<DocavailRole>(
            value: _selectedRole,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _DocavailColors.fieldHint,
            ),
            style: const TextStyle(
              fontSize: 15,
              color: _DocavailColors.heading,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: _DocavailColors.fieldFill,
              prefixIcon: const Icon(
                Icons.badge_outlined,
                color: _DocavailColors.fieldHint,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: _DocavailColors.navy, width: 1.5),
              ),
            ),
            hint: const Text(
              'Select your role',
              style: TextStyle(color: _DocavailColors.fieldHint, fontSize: 15),
            ),
            items: DocavailRole.values
                .map(
                  (role) => DropdownMenuItem<DocavailRole>(
                    value: role,
                    child: Text(role.label),
                  ),
                )
                .toList(),
            onChanged: _isRegistering
                ? null
                : (role) => setState(() => _selectedRole = role),
          ),
        ),
      ),
    );
  }

  Widget _buildProceedButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isRegistering ? null : _finishSetup,
        style: ElevatedButton.styleFrom(
          backgroundColor: _DocavailColors.darkBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              _DocavailColors.darkBlue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isRegistering
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Proceed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}