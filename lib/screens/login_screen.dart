import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Brand colors pulled from the Docavail mockup.
class _DocavailColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const fieldFill = Color(0xFFF0F1F5);
  static const fieldHint = Color(0xFF9AA1B2);
  static const divider = Color(0xFFD8DBE4);
  static const gradientTop = Color(0xFFEDEFFA);
  static const gradientBottom = Color(0xFFCFF3E6);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    // TODO: hook up OTP request flow.
    FocusScope.of(context).unfocus();
  }

  void _loginWithProviderId() {
    // TODO: hook up provider ID login flow.
  }

  void _contactSupport() {
    // TODO: hook up contact support flow.
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
                _buildSignInCard(context),
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

  Widget _buildSignInCard(BuildContext context) {
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
            'Sign In',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          _buildPhoneField(),
          const SizedBox(height: 20),
          _buildSendOtpButton(),
          const SizedBox(height: 20),
          _buildOrDivider(),
          const SizedBox(height: 20),
          _buildProviderIdButton(),
          const SizedBox(height: 24),
          _buildSupportRow(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 15, color: _DocavailColors.heading),
      decoration: InputDecoration(
        hintText: '+1 (555) 000-0000',
        hintStyle: const TextStyle(color: _DocavailColors.fieldHint),
        prefixIcon: const Icon(
          Icons.call_outlined,
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

  Widget _buildSendOtpButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _sendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _DocavailColors.darkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Send OTP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: _DocavailColors.divider)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 13,
              color: _DocavailColors.subtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: _DocavailColors.divider)),
      ],
    );
  }

  Widget _buildProviderIdButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _loginWithProviderId,
        style: OutlinedButton.styleFrom(
          backgroundColor: _DocavailColors.fieldFill,
          foregroundColor: _DocavailColors.heading,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 20, color: _DocavailColors.heading),
            SizedBox(width: 10),
            Text(
              'Login with Provider ID',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportRow() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13.5,
            color: _DocavailColors.subtitle,
          ),
          children: [
            const TextSpan(text: 'Need help accessing your account? '),
            TextSpan(
              text: 'Contact Support',
              style: const TextStyle(
                color: _DocavailColors.navy,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()..onTap = _contactSupport,
            ),
          ],
        ),
      ),
    );
  }
}