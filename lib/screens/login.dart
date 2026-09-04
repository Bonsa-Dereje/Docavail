import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_shell.dart';

/// Brand colors pulled from the Docavail mockup.
/// Kept in sync with the palette used in userinfro.dart / pin.dart.
class _IdLoginColors {
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
// with the constant of the same name in userinfro.dart / pin.dart.
const String _apiBaseUrl = 'https://docavail-endpoints.vercel.app/api';

/// Standalone "ID Card" login screen — just an ID number and a PIN.
///
/// Reached either from login_screen.dart's "Login with ID Card" button
/// (fields start empty) or from userinfro.dart's "Login Instead" card
/// when the background existing-user check already found a match
/// (the ID number is pre-filled from what they typed).
class IdLoginScreen extends StatefulWidget {
  const IdLoginScreen({super.key, this.idNumber, this.phoneNumber});

  final String? idNumber;
  final String? phoneNumber;

  @override
  State<IdLoginScreen> createState() => _IdLoginScreenState();
}

class _IdLoginScreenState extends State<IdLoginScreen> {
  late final TextEditingController _idController =
      TextEditingController(text: widget.idNumber ?? '');
  final TextEditingController _pinController = TextEditingController();

  bool _obscurePin = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final idNumber = _idController.text.trim();
    final pin = _pinController.text.trim();

    if (idNumber.isEmpty) {
      _showMessage('Enter your ID number first.');
      return;
    }
    if (pin.length < 4) {
      _showMessage('Enter a PIN of at least 4 digits.');
      return;
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
              'action': 'login',
              'id_number': idNumber,
              if (widget.phoneNumber != null) 'phone_number': widget.phoneNumber,
              'pin': pin,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      final match = body['match'] == true;
      if (response.statusCode == 200 && match) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AppShell()),
        );
      } else {
        _showMessage('Incorrect ID or PIN. Please try again.');
      }
    } catch (e) {
      debugPrint('ID login error: $e');
      if (mounted) _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            colors: [_IdLoginColors.gradientTop, _IdLoginColors.gradientBottom],
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
                _buildLoginCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _IdLoginColors.heading,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Login with your ID number and PIN.',
          style: TextStyle(fontSize: 14, color: _IdLoginColors.subtitle),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
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
            'Login',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _IdLoginColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your ID number and PIN to sign in.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _IdLoginColors.subtitle),
          ),
          const SizedBox(height: 24),
          _buildLabel('ID No.'),
          const SizedBox(height: 8),
          _buildIdField(),
          const SizedBox(height: 20),
          _buildLabel('PIN'),
          const SizedBox(height: 8),
          _buildPinField(),
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
          color: _IdLoginColors.heading,
        ),
      );

  Widget _buildIdField() {
    return TextField(
      controller: _idController,
      enabled: !_isSubmitting,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontSize: 15, color: _IdLoginColors.heading),
      decoration: InputDecoration(
        hintText: 'e.g. EMP-00231',
        hintStyle: const TextStyle(color: _IdLoginColors.fieldHint),
        prefixIcon: const Icon(
          Icons.credit_card_outlined,
          color: _IdLoginColors.fieldHint,
          size: 20,
        ),
        filled: true,
        fillColor: _IdLoginColors.fieldFill,
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
          borderSide: const BorderSide(color: _IdLoginColors.navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _pinController,
      enabled: !_isSubmitting,
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: const TextStyle(
        fontSize: 15,
        color: _IdLoginColors.heading,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••',
        hintStyle: const TextStyle(color: _IdLoginColors.fieldHint),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: _IdLoginColors.fieldHint,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _IdLoginColors.fieldHint,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePin = !_obscurePin),
        ),
        filled: true,
        fillColor: _IdLoginColors.fieldFill,
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
          borderSide: const BorderSide(color: _IdLoginColors.navy, width: 1.5),
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
          backgroundColor: _IdLoginColors.darkBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _IdLoginColors.darkBlue.withValues(alpha: 0.6),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Login',
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
