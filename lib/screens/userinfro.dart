import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Brand colors pulled from the Docavail mockup.
/// Kept in sync with the palette used in login_screen.dart.
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

/// The roles a new user can register as.
enum DocavailRole {
  doctor('Dr.'),
  triageNurse('Triage Nurse'),
  reception('Reception');

  const DocavailRole(this.label);
  final String label;
}

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();

  DocavailRole? _selectedRole;
  bool _isRegistering = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Finishes account setup, then hands off to AppShell — which opens on
  /// the Queue tab (queue.dart), complete with the shared bottom nav bar
  /// that every tab (Queue, Patient Brief, Profile, …) renders inside.
  Future<void> _finishSetup() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Enter your name first.');
      return;
    }
    if (_selectedRole == null) {
      _showMessage('Select a role to continue.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = true);

    try {
      // TODO: wire this up to the actual registration endpoint.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    } catch (e) {
      if (mounted) _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
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
          _buildDoneButton(),
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

  Widget _buildDoneButton() {
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
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.check_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}