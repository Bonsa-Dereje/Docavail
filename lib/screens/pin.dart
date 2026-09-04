import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_shell.dart';
import '../services/auth_service.dart';
import 'userinfro.dart' show DocavailRole, DocavailRoleApi;

/// Brand colors pulled from the Docavail mockup.
/// Kept in sync with the palette used in userinfro.dart / login_screen.dart.
class _PinColors {
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
// with the constant of the same name in userinfro.dart / login.dart.
const String _apiBaseUrl = 'https://docavail-endpoints.vercel.app/api';

/// PIN entry screen.
///
/// - [isLogin] == false (default): "create a PIN" flow — PIN + confirm PIN
///   + "Create Account" button, which hashes and writes the new user via
///   userinfo.js, then opens patients.dart.
/// - [isLogin] == true: single PIN field + "Login" button, which checks
///   the PIN against the stored hash via userinfo.js, then opens
///   patients.dart on a match.
///
/// [idNumber] is always known by the time this screen is reached (it's
/// collected on userinfro.dart) and is shown as a locked field at the top
/// of the card so the user can confirm it without being able to edit it.
class PinScreen extends StatefulWidget {
  const PinScreen({
    super.key,
    required this.fullName,
    required this.role,
    required this.idNumber,
    this.isLogin = false,
    this.phoneNumber,
  });

  final String fullName;
  final DocavailRole role;
  final String idNumber;
  final bool isLogin;
  final String? phoneNumber;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();

    if (pin.length < 4) {
      _showMessage('Enter a PIN of at least 4 digits.');
      return;
    }

    if (!widget.isLogin) {
      final confirmPin = _confirmPinController.text.trim();
      if (confirmPin != pin) {
        _showMessage("PINs don't match.");
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse('$_apiBaseUrl/userinfo');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': widget.isLogin ? 'login' : 'create',
              'full_name': widget.fullName,
              'role': widget.role.apiValue,
              'id_number': widget.idNumber,
              if (widget.phoneNumber != null) 'phone_number': widget.phoneNumber,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      debugPrint('PIN response ${response.statusCode}: $body');

      if (widget.isLogin) {
        final match = body['match'] == true;
        if (response.statusCode == 200 && match) {
          final token = body['token'] as String?;
          if (token != null) await AuthService.instance.saveToken(token);
          if (!mounted) return;
          _goToPatients();
        } else {
          _showMessage('Incorrect PIN. Please try again.');
        }
        return;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = body['token'] as String?;
        if (token != null) await AuthService.instance.saveToken(token);
        if (!mounted) return;
        _goToPatients();
      } else if (response.statusCode == 409) {
        _showMessage('Account already exists. Please log in instead.');
      } else {
        _showMessage(
          (body['error'] as String?) ?? 'Something went wrong. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('PIN submit error: $e');
      if (mounted) _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToPatients() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AppShell()),
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
            colors: [_PinColors.gradientTop, _PinColors.gradientBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 64),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildPinCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.isLogin ? 'Welcome back' : 'Set up your PIN',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _PinColors.heading,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.fullName,
          style: const TextStyle(fontSize: 14, color: _PinColors.subtitle),
        ),
      ],
    );
  }

  Widget _buildPinCard() {
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
          Text(
            widget.isLogin ? 'Enter your PIN' : 'Create a PIN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _PinColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isLogin
                ? 'Enter your PIN to sign in to your account.'
                : "Choose a PIN you'll use to sign in from now on.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _PinColors.subtitle),
          ),
          const SizedBox(height: 24),
          _buildLabel('ID No.'),
          const SizedBox(height: 8),
          _buildIdDisplayField(),
          const SizedBox(height: 20),
          _buildLabel('PIN'),
          const SizedBox(height: 8),
          _buildPinField(
            controller: _pinController,
            obscure: _obscurePin,
            onToggleObscure: () => setState(() => _obscurePin = !_obscurePin),
          ),
          if (!widget.isLogin) ...[
            const SizedBox(height: 20),
            _buildLabel('Confirm PIN'),
            const SizedBox(height: 8),
            _buildPinField(
              controller: _confirmPinController,
              obscure: _obscureConfirmPin,
              onToggleObscure: () =>
                  setState(() => _obscureConfirmPin = !_obscureConfirmPin),
            ),
          ],
          const SizedBox(height: 28),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _PinColors.heading,
        ),
      );

  /// Read-only display of the ID number captured on the previous screen —
  /// filled in already, not editable here.
  Widget _buildIdDisplayField() {
    return TextField(
      controller: TextEditingController(text: widget.idNumber),
      enabled: false,
      style: const TextStyle(fontSize: 15, color: _PinColors.heading),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.credit_card_outlined,
          color: _PinColors.fieldHint,
          size: 20,
        ),
        filled: true,
        fillColor: _PinColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isSubmitting,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: const TextStyle(
        fontSize: 15,
        color: _PinColors.heading,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••',
        hintStyle: const TextStyle(color: _PinColors.fieldHint),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: _PinColors.fieldHint,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _PinColors.fieldHint,
            size: 20,
          ),
          onPressed: onToggleObscure,
        ),
        filled: true,
        fillColor: _PinColors.fieldFill,
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
          borderSide: const BorderSide(color: _PinColors.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _PinColors.darkBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _PinColors.darkBlue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isLogin ? 'Login' : 'Create Account',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}