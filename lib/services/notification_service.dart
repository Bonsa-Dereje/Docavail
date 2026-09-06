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

  Future<void>? _initFuture;

  /// Sets up the plugin (channels, tap handler) and requests notification
  /// permission. Idempotent — repeated calls settle on one initialization.
  Future<void> initialize() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

    // Android 13+ gates notifications behind a runtime permission, and iOS
    // wants an explicit opt-in — ask for both up front so the first
    // assignment alert isn't silently dropped.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
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
  Future<void> showNewPatientAssignment(NewPatientNotification notification) async {
    await initialize();
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
  }
}