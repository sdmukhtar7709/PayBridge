import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String?> _tapStreamController = StreamController<String?>.broadcast();
  final StreamController<int> _badgeCountController = StreamController<int>.broadcast();
  final StreamController<List<LocalNotificationItem>> _notificationListController =
      StreamController<List<LocalNotificationItem>>.broadcast();
  final Map<int, Timer> _autoCancelTimers = {};
  final Set<int> _activeNotificationIds = {};
  final Map<int, LocalNotificationItem> _notificationItems = {};

  bool _initialized = false;
  int _notificationId = 1000;
  int _badgeCount = 0;

  Stream<String?> get onNotificationTap => _tapStreamController.stream;
  Stream<int> get onBadgeCount => _badgeCountController.stream;
  int get badgeCount => _badgeCount;
  Stream<List<LocalNotificationItem>> get onNotificationList => _notificationListController.stream;
  List<LocalNotificationItem> get activeNotifications =>
      _notificationItems.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void markAllSeen() {
    if (_badgeCount == 0 && _activeNotificationIds.isEmpty) return;
    _activeNotificationIds.clear();
    _badgeCount = 0;
    _badgeCountController.add(_badgeCount);
  }

  void clearAllNotifications() {
    for (final timer in _autoCancelTimers.values) {
      timer.cancel();
    }
    _autoCancelTimers.clear();
    _activeNotificationIds.clear();
    _notificationItems.clear();
    _badgeCount = 0;
    _badgeCountController.add(_badgeCount);
    _notificationListController.add(const []);
  }

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _acknowledgeNotification(response.id);
        _tapStreamController.add(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showIncomingTransactionRequest({required String requesterName}) async {
    await init();

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
      channelDescription: 'Alerts the agent when a user requests a transaction.',
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
      channelDescription: 'Updates for user transaction requests and status changes.',
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

  Future<void> dispose() async {
    for (final timer in _autoCancelTimers.values) {
      timer.cancel();
    }
    _autoCancelTimers.clear();
    _activeNotificationIds.clear();
    _notificationItems.clear();
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
