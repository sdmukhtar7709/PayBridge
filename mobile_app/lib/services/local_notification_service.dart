import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String?> _tapStreamController =
      StreamController<String?>.broadcast();
  final StreamController<int> _badgeCountController =
      StreamController<int>.broadcast();
  final StreamController<List<LocalNotificationItem>>
  _notificationListController =
      StreamController<List<LocalNotificationItem>>.broadcast();
  final Map<int, Timer> _autoCancelTimers = {};
  final Set<int> _activeNotificationIds = {};
  final Map<int, LocalNotificationItem> _notificationItems = {};
  final Map<String, DateTime> _recentNotificationKeys = <String, DateTime>{};
  Timer? _loginCleanupTimer;

  bool _initialized = false;
  int _notificationId = 1000;
  int _badgeCount = 0;
  static const Duration _dedupeWindow = Duration(seconds: 20);

  Stream<String?> get onNotificationTap => _tapStreamController.stream;
  Stream<int> get onBadgeCount => _badgeCountController.stream;
  int get badgeCount => _badgeCount;
  Stream<List<LocalNotificationItem>> get onNotificationList =>
      _notificationListController.stream;
  List<LocalNotificationItem> get activeNotifications =>
      _notificationItems.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void markAllSeen() {
    if (_badgeCount == 0 && _activeNotificationIds.isEmpty) return;
    _activeNotificationIds.clear();
    _badgeCount = 0;
    _badgeCountController.add(_badgeCount);
  }

  void clearAllNotifications() {
    if (!kIsWeb) {
      unawaited(_plugin.cancelAll());
    }

    for (final timer in _autoCancelTimers.values) {
      timer.cancel();
    }
    _autoCancelTimers.clear();
    _activeNotificationIds.clear();
    _notificationItems.clear();
    _recentNotificationKeys.clear();
    _badgeCount = 0;
    _badgeCountController.add(_badgeCount);
    _notificationListController.add(const []);
  }

  void resetForNewLogin({Duration clearAfter = const Duration(minutes: 2)}) {
    // Drop previously cached notifications at the start of every fresh login.
    clearAllNotifications();

    _loginCleanupTimer?.cancel();
    _loginCleanupTimer = Timer(clearAfter, () {
      clearAllNotifications();
    });
  }

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _acknowledgeNotification(response.id);
        _tapStreamController.add(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showIncomingTransactionRequest({
    required String requesterName,
  }) async {
    await init();

    if (_shouldSkipDuplicate(
      category: 'incoming_request',
      title: 'New Transaction Request',
      message: '$requesterName requested for transaction. Tap to view.',
      payload: 'open_live_requests',
    )) {
      return;
    }

    if (kIsWeb) {
      _registerNotification(
        LocalNotificationItem(
          id: _notificationId++,
          title: 'New Transaction Request',
          message: '$requesterName requested for transaction. Tap to view.',
          payload: 'open_live_requests',
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'agent_live_requests',
      'Agent Live Requests',
      channelDescription:
          'Alerts the agent when a user requests a transaction.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.message,
      ticker: 'New transaction request',
    );

    const details = NotificationDetails(android: androidDetails);

    final id = _notificationId++;
    await _plugin.show(
      id,
      'New Transaction Request',
      '$requesterName requested for transaction. Tap to view.',
      details,
      payload: 'open_live_requests',
    );
    _registerNotification(
      LocalNotificationItem(
        id: id,
        title: 'New Transaction Request',
        message: '$requesterName requested for transaction. Tap to view.',
        payload: 'open_live_requests',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> showUserStatusNotification({
    required String title,
    required String message,
    required String payload,
  }) async {
    await init();

    if (_shouldSkipDuplicate(
      category: 'user_status',
      title: title,
      message: message,
      payload: payload,
    )) {
      return;
    }

    if (kIsWeb) {
      _registerNotification(
        LocalNotificationItem(
          id: _notificationId++,
          title: title,
          message: message,
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'user_transaction_updates',
      'User Transaction Updates',
      channelDescription:
          'Updates for user transaction requests and status changes.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.status,
    );

    const details = NotificationDetails(android: androidDetails);

    final id = _notificationId++;
    await _plugin.show(id, title, message, details, payload: payload);
    _registerNotification(
      LocalNotificationItem(
        id: id,
        title: title,
        message: message,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> showAgentStatusNotification({
    required String title,
    required String message,
    required String payload,
  }) async {
    await init();

    if (_shouldSkipDuplicate(
      category: 'agent_status',
      title: title,
      message: message,
      payload: payload,
    )) {
      return;
    }

    if (kIsWeb) {
      _registerNotification(
        LocalNotificationItem(
          id: _notificationId++,
          title: title,
          message: message,
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'agent_status_updates',
      'Agent Status Updates',
      channelDescription: 'Alerts agents when their account status changes.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.status,
    );

    const details = NotificationDetails(android: androidDetails);

    final id = _notificationId++;
    await _plugin.show(id, title, message, details, payload: payload);
    _registerNotification(
      LocalNotificationItem(
        id: id,
        title: title,
        message: message,
        payload: payload,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _registerNotification(LocalNotificationItem item) {
    if (_activeNotificationIds.add(item.id)) {
      _badgeCount += 1;
      _badgeCountController.add(_badgeCount);
    }
    _notificationItems[item.id] = item;
    _notificationListController.add(activeNotifications);
    _scheduleAutoCancel(item.id);
  }

  void _acknowledgeNotification(int? id) {
    if (id == null) return;
    if (_activeNotificationIds.remove(id)) {
      _badgeCount = _badgeCount > 0 ? _badgeCount - 1 : 0;
      _badgeCountController.add(_badgeCount);
    }
    _notificationItems.remove(id);
    _notificationListController.add(activeNotifications);
    _autoCancelTimers.remove(id)?.cancel();
  }

  void _expireNotification(int id) {
    if (!kIsWeb) {
      _plugin.cancel(id);
    }
    if (_activeNotificationIds.remove(id)) {
      _badgeCount = _badgeCount > 0 ? _badgeCount - 1 : 0;
      _badgeCountController.add(_badgeCount);
    }
    _notificationItems.remove(id);
    _notificationListController.add(activeNotifications);
  }

  void _scheduleAutoCancel(int id) {
    _autoCancelTimers[id]?.cancel();
    _autoCancelTimers[id] = Timer(const Duration(minutes: 10), () {
      _expireNotification(id);
      _autoCancelTimers.remove(id);
    });
  }

  bool _shouldSkipDuplicate({
    required String category,
    required String title,
    required String message,
    required String payload,
  }) {
    final now = DateTime.now();
    _recentNotificationKeys.removeWhere(
      (_, ts) => now.difference(ts) > _dedupeWindow,
    );

    final key = '$category|$title|$message|$payload';
    final previous = _recentNotificationKeys[key];
    if (previous != null && now.difference(previous) <= _dedupeWindow) {
      return true;
    }

    _recentNotificationKeys[key] = now;
    return false;
  }

  Future<void> dispose() async {
    _loginCleanupTimer?.cancel();
    for (final timer in _autoCancelTimers.values) {
      timer.cancel();
    }
    _autoCancelTimers.clear();
    _activeNotificationIds.clear();
    _notificationItems.clear();
    _recentNotificationKeys.clear();
    await _badgeCountController.close();
    await _notificationListController.close();
    await _tapStreamController.close();
  }
}

class LocalNotificationItem {
  final int id;
  final String title;
  final String message;
  final String payload;
  final DateTime createdAt;

  const LocalNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.payload,
    required this.createdAt,
  });
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // No-op: app opens on tap. Foreground handling is wired through onNotificationTap stream.
}
