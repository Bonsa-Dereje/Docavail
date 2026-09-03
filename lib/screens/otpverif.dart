import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart' show OtpGatewayClient, OtpGatewayException;
import 'userinfro.dart';

/// Brand colors pulled from the Docavail mockup.
/// Kept in sync with the palette used in login_screen.dart.
class _DocavailColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const fieldFill = Color(0xFFF0F1F5);
  static const success = Color(0xFF1F9D55);
  static const error = Color(0xFFD64545);
  static const gradientTop = Color(0xFFEDEFFA);
  static const gradientBottom = Color(0xFFCFF3E6);
}

const int _otpLength = 6;
const int _resendCooldownSeconds = 30;

/// Thrown for any failure talking to the OTP verification endpoint.
class OtpVerifyException implements Exception {
  OtpVerifyException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin client for POST https://sms-gateway-router.vercel.app/api/otp/otpverif
/// (see 1788471551557_otp_supabase_endpoints.md — same host as
/// OtpGatewayClient's queue endpoint and main.dart's otpwrite/otpdelete calls).
class OtpVerifyClient {
  OtpVerifyClient({
    this.baseUrl = 'https://sms-gateway-router.vercel.app',
  });

  final String baseUrl;

  /// Returns true if the code matches what's on file for [phoneNumber].
  Future<bool> verify({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/otp/otpverif');

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'otp_code': otpCode,
        }),
      );
    } on Exception {
      throw OtpVerifyException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      throw OtpVerifyException(
        'Failed to verify code (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['match'] == true;
  }
}

class OtpVerifScreen extends StatefulWidget {
  const OtpVerifScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpVerifScreen> createState() => _OtpVerifScreenState();
}

enum _OtpBoxState { neutral, success, error }

class _OtpVerifScreenState extends State<OtpVerifScreen> {
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  final OtpGatewayClient _otpGateway = OtpGatewayClient();
  final OtpVerifyClient _otpVerify = OtpVerifyClient();

  _OtpBoxState _boxState = _OtpBoxState.neutral;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _secondsRemaining = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _secondsRemaining = _resendCooldownSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (_boxState != _OtpBoxState.neutral) {
      setState(() {
        _boxState = _OtpBoxState.neutral;
        _errorMessage = null;
      });
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_enteredCode.length == _otpLength) {
      FocusScope.of(context).unfocus();
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) return;
    final code = _enteredCode;
    if (code.length != _otpLength) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final matched = await _otpVerify.verify(
        phoneNumber: widget.phoneNumber,
        otpCode: code,
      );

      if (!mounted) return;

      if (matched) {
        setState(() => _boxState = _OtpBoxState.success);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UserInfoScreen()),
        );
      } else {
        setState(() {
          _boxState = _OtpBoxState.error;
          _errorMessage = 'That code doesn\'t match. Try again.';
        });
      }
    } on OtpVerifyException catch (e) {
      if (mounted) {
        setState(() {
          _boxState = _OtpBoxState.error;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _boxState = _OtpBoxState.error;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  /// Pulls digits out of [text] (ignoring spaces/dashes/etc. so a code
  /// copied from an SMS like "Your code is 483920." still works), spreads
  /// them across the boxes, and either advances focus or verifies once
  /// full — mirrors what typing the same digits one at a time would do.
  void _applyPastedCode(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _showMessage('Clipboard doesn\'t contain a code.');
      return;
    }

    final code = digits.substring(0, digits.length.clamp(0, _otpLength));

    setState(() {
      _boxState = _OtpBoxState.neutral;
      _errorMessage = null;
      for (var i = 0; i < _otpLength; i++) {
        _controllers[i].text = i < code.length ? code[i] : '';
      }
    });

    if (code.length == _otpLength) {
      FocusScope.of(context).unfocus();
      _verifyCode();
    } else {
      _focusNodes[code.length].requestFocus();
    }
  }

  Future<void> _showPasteMenu(Offset position) async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text;
    if (text == null || text.trim().isEmpty) {
      if (mounted) _showMessage('Clipboard is empty.');
      return;
    }

    if (!mounted) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem<String>(value: 'paste', child: Text('Paste')),
      ],
    );

    if (selected == 'paste') {
      _applyPastedCode(text);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await _otpGateway.queueOtp(
        phoneNumber: widget.phoneNumber,
        otpLength: _otpLength,
        specialText: 'Do not share this code with anyone.',
      );
      if (!mounted) return;
      _clearBoxes();
      setState(() {
        _boxState = _OtpBoxState.neutral;
        _errorMessage = null;
      });
      _startResendCountdown();
      _showMessage('A new code is on its way.');
    } on OtpGatewayException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not resend the code. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
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
                _buildVerifyCard(context),
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

  Widget _buildVerifyCard(BuildContext context) {
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
            'Verify Your Number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _DocavailColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit code sent to ${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _DocavailColors.subtitle,
            ),
          ),
          const SizedBox(height: 28),
          _buildOtpBoxes(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _DocavailColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_isVerifying) const Center(child: _VerifyingIndicator()),
          const SizedBox(height: 24),
          _buildResendRow(),
        ],
      ),
    );
  }

  Widget _buildOtpBoxes() {
    final Color borderColor = switch (_boxState) {
      _OtpBoxState.success => _DocavailColors.success,
      _OtpBoxState.error => _DocavailColors.error,
      _OtpBoxState.neutral => Colors.transparent,
    };
    final Color fillColor = switch (_boxState) {
      _OtpBoxState.success => _DocavailColors.success.withValues(alpha: 0.10),
      _OtpBoxState.error => _DocavailColors.error.withValues(alpha: 0.08),
      _OtpBoxState.neutral => _DocavailColors.fieldFill,
    };
    final Color textColor = switch (_boxState) {
      _OtpBoxState.success => _DocavailColors.success,
      _OtpBoxState.error => _DocavailColors.error,
      _OtpBoxState.neutral => _DocavailColors.heading,
    };

    // Fixed-width boxes with a spaceBetween Row don't actually guarantee
    // spacing — on narrower phones the 6 boxes plus the card's horizontal
    // padding can exceed the available width, so the row overflows and the
    // boxes end up squeezed on top of each other instead of wrapping.
    // Expanded + explicit gap SizedBoxes gives each box a fair, bounded
    // share of whatever width is actually available, so they never overlap.
    const double gap = 8;

    Widget box(int index) {
      return AspectRatio(
        aspectRatio: 44 / 56,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_isVerifying,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: fillColor,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _boxState == _OtpBoxState.neutral
                    ? _DocavailColors.navy
                    : borderColor,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_otpLength * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: gap);
        final index = i ~/ 2;
        // Long-press the first box to bring up a Paste option, which
        // spreads the clipboard's code across all the boxes at once.
        if (index == 0) {
          return Expanded(
            child: GestureDetector(
              onLongPressStart: (details) => _showPasteMenu(details.globalPosition),
              child: box(index),
            ),
          );
        }
        return Expanded(child: box(index));
      }),
    );
  }

  Widget _buildResendRow() {
    final bool canResend = _secondsRemaining == 0 && !_isResending;
    final String label = _secondsRemaining > 0
        ? 'Resend code in 0:${_secondsRemaining.toString().padLeft(2, '0')}'
        : (_isResending ? 'Resending…' : 'Resend code');

    return Center(
      child: TextButton(
        onPressed: canResend ? _resendCode : null,
        style: TextButton.styleFrom(
          foregroundColor:
              canResend ? _DocavailColors.navy : _DocavailColors.subtitle,
          disabledForegroundColor: _DocavailColors.subtitle,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _VerifyingIndicator extends StatelessWidget {
  const _VerifyingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: _DocavailColors.navy,
      ),
    );
  }
}