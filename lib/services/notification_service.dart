import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Data passed along with a "new patient assigned" notification, decoded
/// from the notification's payload so a tap can deep-link into that
/// patient's brief.
class NewPatientNotification {
  final String patientName;
  final String complaint;
  final String? patientId;
  final String? assignmentId;

  const NewPatientNotification({
    required this.patientName,
    required this.complaint,
    this.patientId,
    this.assignmentId,
  });
}

/// Single place that owns device-side notifications for Docavail.
///
/// The assignment itself happens server-side (POST /api/patient_assign
/// {action:"run"} on the Vercel host) with no push channel to the device,
/// so instead of waiting for an FCM payload the Queue screen's 1-second
/// poll detects freshly-appeared assignments and asks this service to raise
/// a local notification with the patient's name and case. Calling code
/// decides exactly what counts as "new" and passes it in here.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Called when the user taps a "new patient" notification. main.dart
  /// wires this up to deep-link into the patient's brief using the
  /// global navigator key.
  static void Function(NewPatientNotification notification)? onNotificationTap;

  static const String _channelId = 'new_patient_assignments';
  static const String _channelName = 'New Patient Assignments';
  static const String _channelDescription =
      'Notifications when a new patient is assigned to you';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Notification ids are just an incrementing counter here — nothing about
  /// a local "new patient" alert needs to be stable or deduplicated by id.
  int _nextId = 0;

  /// Plugin/channel setup state. Kept as plain flags instead of a cached
  /// Future so a failed init (e.g. a platform channel race during app
  /// startup) doesn't permanently poison every later show() call — the next
  /// notification simply retries.
  bool _initialized = false;
  bool _permissionRequested = false;

  /// Sets up the plugin (channels, tap handler) and requests notification
  /// permission. Idempotent and safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      // The launcher PNG is a full-color square — wrong for the status-bar
      // glyph Android places next to the app name. ic_notification is a
      // white-on-transparent medical cross that the system tints properly.
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    _initialized = true;
    // Kick off the OS permission prompt without blocking callers; on first
    // launch this shows the dialog immediately, and on later runs it's a
    // no-op. Each alert also re-checks via _requestPermissionOnce.
    unawaited(_requestPermissionOnce());
  }

  /// Requests the runtime notification permission (Android 13+/iOS). Called
  /// once — the OS only shows the dialog a single time. Deliberately not
  /// awaited by [showNewPatientAssignment]'s caller path in a way that
  /// blocks, so a pending/dismissed dialog can never stall an alert.
  Future<void> _requestPermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      // Android 13+ gates notifications behind a runtime permission, and
      // iOS wants an explicit opt-in.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (err) {
      debugPrint('NotificationService: permission request failed: $err');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(
        NewPatientNotification(
          patientName: data['patientName'] as String? ?? '',
          complaint: data['complaint'] as String? ?? '',
          patientId: data['patientId'] as String?,
          assignmentId: data['assignmentId'] as String?,
        ),
      );
    } catch (_) {
      debugPrint('NotificationService: ignored malformed notification payload');
    }
  }

  /// Raises a high-priority "New Patient" alert for a newly assigned
  /// patient. [complaint] is the chief complaint (the patient's case).
  ///
  /// Runs entirely inside try/catch so a platform hiccup can never crash the
  /// queue poll that calls this, and any failure is logged (visible in
  /// `flutter run` / `adb logcat`) instead of vanishing silently.
  Future<void> showNewPatientAssignment(NewPatientNotification notification) async {
    try {
      await initialize();
      await _requestPermissionOnce();
      await _plugin.show(
        id: _nextId++,
        title: 'New Patient',
        body: 'Case: ${notification.complaint}',
        notificationDetails: const NotificationDetails(
android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Shows the actual Docavail logo alongside the app name at the
          // top of the notification card, like other apps' headers.
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode({
          'patientName': notification.patientName,
          'complaint': notification.complaint,
          'patientId': notification.patientId,
          'assignmentId': notification.assignmentId,
        }),
      );
      debugPrint(
        'NotificationService: posted new-patient alert for '
        '${notification.patientName}',
      );
    } catch (err) {
      debugPrint('NotificationService: failed to post notification: $err');
    }
  }
}