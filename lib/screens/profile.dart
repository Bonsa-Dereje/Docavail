import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/consultation_state.dart';
import 'login_screen.dart' show LoginScreen;

/// Brand + status colors used across the Profile / Status Control screen.
class _ProfileColors {
  static const navy = Color(0xFF0D2B9E);
  static const darkBlue = Color(0xFF0B2694);
  static const heading = Color(0xFF1B1F2A);
  static const subtitle = Color(0xFF7A8194);
  static const background = Color(0xFFF4F5F8);
  static const divider = Color(0xFFE3E5EC);
  static const onDutyGreen = Color(0xFF16A673);
}

enum _AvailabilityMode { hospital, consulting, onBreak, leaving }

/// Simple pulsing placeholder block used while user details are loading.
class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.35,
    end: 0.85,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: child,
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _ProfileColors.divider,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

const String _apiBaseUrl = 'https://docavail-endpoints.vercel.app/api';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onLoggedOut});

  /// Called after the session token has been revoked server-side (best
  /// effort) and cleared from secure storage. Use this to navigate to
  /// your login screen, e.g.:
  ///   ProfileScreen(onLoggedOut: () => Navigator.of(context)
  ///       .pushAndRemoveUntil(
  ///         MaterialPageRoute(builder: (context) => const LoginScreen()),
  ///         (route) => false,
  ///       ))
  /// If omitted, ProfileScreen falls back to pushing LoginScreen and
  /// clearing the navigation stack itself.
  final VoidCallback? onLoggedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _storage = FlutterSecureStorage();

  bool _onDuty = true;
  _AvailabilityMode _mode = _AvailabilityMode.hospital;
  String? _lastUpdated;

  /// The number of extra patients the doctor consented to take while in
  /// Leaving mode (their on-screen "how many more?" pick). Shown/revised
  /// via the capacity modal; 0 means "no more patients".
  int _extraPatientLimit = 0;

  bool _statusSyncing = false;

  bool _loggingOut = false;

  bool _loadingUser = true;
  String? _userError;
  String _fullName = '';
  String _idNumber = '';

  @override
  void initState() {
    super.initState();
    // Keep the availability mode in sync with whichever patient is mid-
    // consultation. The Queue screen feeds ConsultationState while it polls
    // GET /api/patient_assign every second, so whenever a consultation
    // starts or ends on the Queue/Patients screens this screen hears about
    // it and reflects it ("Consulting" while active) without the doctor
    // having to touch the status grid.
    ConsultationState.instance.addListener(_onConsultationChanged);
    _loadUser();
  }

  void _onConsultationChanged() {
    if (!mounted) return;
    _syncModeWithConsultation();
  }

  @override
  void dispose() {
    ConsultationState.instance.removeListener(_onConsultationChanged);
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loadingUser = true;
      _userError = null;
    });

    try {
      final token = await _storage.read(key: 'session_token');
      if (token == null || token.isEmpty) {
        setState(() {
          _loadingUser = false;
          _userError = 'Not logged in';
        });
        return;
      }

      final uri = Uri.parse('$_apiBaseUrl/userinfo').replace(
        queryParameters: {'token': token},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _fullName = (body['full_name'] as String?) ?? '';
          _idNumber = (body['id_number'] as String?) ?? '';
          _loadingUser = false;
        });
      } else {
        // 401 (expired/revoked) or any other failure: fall back to
        // login rather than showing stale/blank details.
        setState(() {
          _loadingUser = false;
          _userError = 'Could not load profile';
        });
      }
    } catch (err) {
      setState(() {
        _loadingUser = false;
        _userError = 'Could not load profile';
      });
    }
  }

  static const Map<_AvailabilityMode, String> _modeApiValues = {
    _AvailabilityMode.hospital: 'hospital',
    _AvailabilityMode.consulting: 'consulting',
    _AvailabilityMode.onBreak: 'on_break',
    _AvailabilityMode.leaving: 'leaving',
  };

  String _formatTimeLabel(DateTime dt) {
    final local = dt.toLocal();
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  /// Pushes the current on-duty flag + mode to the backend. Callers apply
  /// the optimistic UI change first, then await this; on failure they
  /// should revert to the previous values themselves. [extraPatientLimit]
  /// is only honored by the backend for the 'leaving' mode — it's ignored
  /// (stored as 0) otherwise.
  Future<bool> _pushStatus({
    required bool onDuty,
    required _AvailabilityMode mode,
    int extraPatientLimit = 0,
  }) async {
    setState(() => _statusSyncing = true);

    try {
      final token = await _storage.read(key: 'session_token');
      if (token == null || token.isEmpty) {
        _showStatusError('Not logged in');
        return false;
      }

      final uri = Uri.parse('$_apiBaseUrl/status_update');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'is_on_duty': onDuty,
          'mode': _modeApiValues[mode],
          'extra_patient_limit': extraPatientLimit,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as Map<String, dynamic>?;
        final updatedAt = status?['updated_at'] as String?;
        setState(() {
          _lastUpdated = updatedAt != null
              ? _formatTimeLabel(DateTime.parse(updatedAt))
              : _formatTimeLabel(DateTime.now());
        });
        return true;
      }

      if (response.statusCode == 401) {
        _showStatusError('Session expired. Please log in again.');
      } else {
        _showStatusError('Could not update status');
      }
      return false;
    } catch (err) {
      _showStatusError('Could not update status');
      return false;
    } finally {
      if (mounted) {
        setState(() => _statusSyncing = false);
      }
    }
  }

  void _showStatusError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    // Best-effort server-side revoke first: this sets revoked_at on the
    // session row so the token can't be replayed even if it leaked
    // somewhere before local storage is cleared. A failure here (e.g. no
    // network) shouldn't trap the user on this screen — we still clear
    // the local token and finish logging out either way.
    try {
      final token = await _storage.read(key: 'session_token');
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('$_apiBaseUrl/logout');
        await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'token': token}),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (err) {
      // Ignore: local logout still proceeds below. The session will
      // still expire on its own after SESSION_TTL_DAYS even if this
      // revoke call never reached the server.
    }

    try {
      await _storage.delete(key: 'session_token');
    } catch (err) {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
      _showStatusError('Could not log out, please try again');
      return;
    }

    if (!mounted) return;
    setState(() => _loggingOut = false);

    if (widget.onLoggedOut != null) {
      widget.onLoggedOut!();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _toggleOnDuty(bool value) async {
    if (_statusSyncing) return;
    final previous = _onDuty;
    setState(() => _onDuty = value);
    final ok = await _pushStatus(onDuty: value, mode: _mode);
    if (!ok && mounted) {
      setState(() => _onDuty = previous);
    }
  }

  Future<void> _selectMode(_AvailabilityMode mode) async {
    if (_statusSyncing) return;
    // Re-tapping the currently active card is normally a no-op, except for
    // Leaving — re-opening it lets the doctor revise how many more patients
    // they'll take before heading off.
    if (mode == _mode && _onDuty && mode != _AvailabilityMode.leaving) return;

    // Picking Leaving first asks the doctor how many more patients they're
    // still willing to take; that number becomes the hard cap the desktop
    // admin may still assign. Cancelling keeps the previous mode.
    int extraPatientLimit = 0;
    if (mode == _AvailabilityMode.leaving) {
      final picked = await _promptExtraPatientLimit();
      if (picked == null) return;
      extraPatientLimit = picked;
    }

    final previousMode = _mode;
    final previousOnDuty = _onDuty;
    final previousLimit = _extraPatientLimit;

    // Picking a work mode is only meaningful while on duty, so selecting
    // any of the four cards auto-enables the "On Duty" toggle too.
    setState(() {
      _mode = mode;
      _onDuty = true;
      _extraPatientLimit = extraPatientLimit;
    });

    final ok = await _pushStatus(
      onDuty: true,
      mode: mode,
      extraPatientLimit: extraPatientLimit,
    );
    if (!ok && mounted) {
      setState(() {
        _mode = previousMode;
        _onDuty = previousOnDuty;
        _extraPatientLimit = previousLimit;
      });
    }
  }

  /// Blurred-background modal that asks "how many more patients would you
  /// take?" with a big number stepper (+/- buttons). Returns the picked
  /// count, or null if the doctor dismissed it.
  Future<int?> _promptExtraPatientLimit() {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Patient capacity',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        // The BackdropFilter here lives in the dialog's own route, so it
        // blurs everything painted beneath it — the whole app behind the
        // modal goes soft while this card sits on top.
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            Center(
              child: _LeavingCapacityModal(
                initialLimit: _extraPatientLimit > 0 ? _extraPatientLimit : 0,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Whether the profile is currently authoring its own mode (e.g. the
  /// doctor picked "Hospital" after a consultation ended) rather than
  /// being overridden by a live consultation. Guards the sync below so it
  /// never fights a manual selection.
  bool _consultationDroveMode = false;

  /// Reconciles the on-screen availability mode with the shared
  /// [ConsultationState]. When a patient is mid-consultation the doctor is
  /// effectively "Consulting", so this auto-switches the mode (and pushes
  /// the same status_update the grid buttons do); once the last
  /// consultation ends it drops back to "Hospital".
  Future<void> _syncModeWithConsultation() async {
    final consulting = ConsultationState.instance.hasActiveConsultation;

    if (consulting) {
      // A consultation is live: force the mode to Consulting so Profile,
      // Queue and Patients all agree, on duty.
      _consultationDroveMode = true;
      if (_mode == _AvailabilityMode.consulting && _onDuty) return;
      setState(() {
        _mode = _AvailabilityMode.consulting;
        _onDuty = true;
      });
      await _pushStatus(onDuty: true, mode: _AvailabilityMode.consulting);
      return;
    }

    // No active consultation: only "un-drive" the mode if the profile had
    // been auto-set to Consulting by an earlier consultation. A manual
    // Hospital/Break/Leaving selection stays untouched.
    if (!_consultationDroveMode) return;
    _consultationDroveMode = false;
    if (_mode == _AvailabilityMode.hospital && _onDuty) return;
    setState(() {
      _mode = _AvailabilityMode.hospital;
      _onDuty = true;
    });
    await _pushStatus(onDuty: true, mode: _AvailabilityMode.hospital);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfileColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status Control',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _ProfileColors.heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your current availability and location.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _ProfileColors.subtitle,
                ),
              ),
              const SizedBox(height: 20),
              _buildDoctorCard(),
              const SizedBox(height: 20),
              _buildAvailabilityGrid(),
              const SizedBox(height: 24),
              _buildLastUpdated(),
              const SizedBox(height: 28),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: _ProfileColors.divider,
                child: Icon(Icons.person,
                    color: _ProfileColors.subtitle, size: 28),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _onDuty
                        ? _ProfileColors.onDutyGreen
                        : _ProfileColors.subtitle,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingUser)
                  _SkeletonBox(width: 140, height: 15)
                else
                  Text(
                    _userError ??
                        (_fullName.isNotEmpty ? _fullName : 'Unknown user'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ProfileColors.heading,
                    ),
                  ),
                const SizedBox(height: 6),
                if (_loadingUser)
                  _SkeletonBox(width: 100, height: 12)
                else if (_userError == null && _idNumber.isNotEmpty)
                  Text(
                    'ID: $_idNumber',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ProfileColors.subtitle,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _onDuty ? 'On Duty' : 'Off Duty',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _onDuty
                      ? _ProfileColors.onDutyGreen
                      : _ProfileColors.subtitle,
                ),
              ),
              const SizedBox(height: 6),
              Switch(
                value: _onDuty,
                onChanged: _statusSyncing ? null : _toggleOnDuty,
                activeThumbColor: Colors.white,
                activeTrackColor: _ProfileColors.navy,
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                  (states) => states.contains(WidgetState.selected)
                      ? const Icon(Icons.check, color: _ProfileColors.navy)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_onDuty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Turn on duty to set your availability.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _ProfileColors.subtitle,
              ),
            ),
          ),
        _buildModeGrid(),
      ],
    );
  }

  Widget _buildModeGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: [
        _buildModeCard(
          mode: _AvailabilityMode.hospital,
          icon: Icons.local_hospital_outlined,
          label: 'Hospital',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.consulting,
          icon: Icons.medical_services_outlined,
          label: 'Consulting',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.onBreak,
          icon: Icons.free_breakfast_outlined,
          label: 'On Break',
        ),
        _buildModeCard(
          mode: _AvailabilityMode.leaving,
          icon: Icons.directions_walk_rounded,
          label: 'Leaving',
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required _AvailabilityMode mode,
    required IconData icon,
    required String label,
  }) {
    // While off duty, no mode is meaningfully "active" — grey every card
    // out rather than keeping the last-picked one highlighted navy. The
    // cards stay tappable: picking one while off duty auto-flips duty on.
    //
    // While a patient is mid-consultation the doctor is effectively
    // Consulting, so the other modes are locked out (grayed + non-tappable)
    // — only the Consulting card stays active/selected.
    final bool inConsultation =
        ConsultationState.instance.hasActiveConsultation;
    final bool showSelected = _mode == mode && _onDuty;
    final bool lockedInConsultation = inConsultation &&
        mode != _AvailabilityMode.consulting;
    final bool grayedOut = !_onDuty || lockedInConsultation;

    return GestureDetector(
      onTap: (_statusSyncing || lockedInConsultation)
          ? null
          : () => _selectMode(mode),
      child: Opacity(
        opacity: grayedOut
            ? 0.45
            : (_statusSyncing && !showSelected ? 0.6 : 1),
        child: Container(
          decoration: BoxDecoration(
            color: showSelected ? _ProfileColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  showSelected ? _ProfileColors.navy : _ProfileColors.divider,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: showSelected ? Colors.white : _ProfileColors.heading,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      showSelected ? Colors.white : _ProfileColors.heading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    final String label = _statusSyncing
        ? 'Updating status…'
        : (_lastUpdated != null
            ? 'Status updated at $_lastUpdated'
            : 'Status not yet synced');

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_statusSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _ProfileColors.subtitle,
              ),
            )
          else
            const Icon(Icons.history_rounded,
                size: 16, color: _ProfileColors.subtitle),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _ProfileColors.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loggingOut ? null : _logout,
        icon: _loggingOut
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : const Icon(Icons.logout_rounded, color: Colors.red),
        label: Text(
          _loggingOut ? 'Logging out…' : 'Log Out',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// The "how many more patients would you take?" card shown over a blurred
/// background when a doctor picks Leaving. A single big number with a
/// round plus/minus button beside each side, so the doctor can step the
/// count up and down freely, plus confirm/cancel. The picked number is
/// what the desktop admin is capped to — they can't stack more than this
/// many extra patients onto a leaving doctor.
class _LeavingCapacityModal extends StatefulWidget {
  const _LeavingCapacityModal({this.initialLimit = 0});

  final int initialLimit;

  @override
  State<_LeavingCapacityModal> createState() => _LeavingCapacityModalState();
}

class _LeavingCapacityModalState extends State<_LeavingCapacityModal> {
  // A live draft of the count, reset each time the modal opens.
  late int _draft = widget.initialLimit;

  void _change(int delta) {
    // Floor at 0 ("no more patients") and cap at a generous 99 so the
    // number stays tappable/large; nobody realistically takes more than
    // a few dozen extra.
    setState(() {
      _draft = (_draft + delta).clamp(0, 99);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Leaving',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _ProfileColors.subtitle,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How many more patients would you take?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ProfileColors.heading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The desktop admin can\u2019t assign you more than this until you\u2019re back from your break.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: _ProfileColors.subtitle,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundStepButton(
                  icon: Icons.remove_rounded,
                  onTap: _draft <= 0 ? null : () => _change(-1),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    '$_draft',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 64,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: _ProfileColors.navy,
                    ),
                  ),
                ),
                _RoundStepButton(
                  icon: Icons.add_rounded,
                  onTap: _draft >= 99 ? null : () => _change(1),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ProfileColors.heading,
                      side: const BorderSide(color: _ProfileColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ProfileColors.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single large round +/- button for the capacity stepper. Disabled at
/// the floor/ceiling by passing a null [onTap].
class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? _ProfileColors.navy : _ProfileColors.divider,
        ),
        child: Icon(
          icon,
          size: 32,
          color: enabled ? Colors.white : _ProfileColors.subtitle,
        ),
      ),
    );
  }
}