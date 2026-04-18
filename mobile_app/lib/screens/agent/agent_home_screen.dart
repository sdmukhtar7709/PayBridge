import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:async';

import '../../services/agent_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/location_service.dart';
import 'agent_profile_screen.dart';
import 'transactions/agent_transaction_success_screen.dart';
import 'transactions/agent_transactions_screen.dart';
import '../shared/nearby_map_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  final bool openLiveRequestsOnLoad;

  const AgentHomeScreen({super.key, this.openLiveRequestsOnLoad = false});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen>
    with WidgetsBindingObserver {
  bool _isOnline = true;
  bool _isBanned = false;
  bool _isVerified = false;
  bool _hasShownBanNotification = false;
  bool _hasShownUnbanNotification = false;
  bool _hasShownVerifiedNotification = false;
  int _currentIndex = 0;

  String _agentName = 'Agent';
  String _cityName = 'Your City';
  Uint8List? _profilePhotoBytes;
  double? _averageRating;
  int _ratingCount = 0;

  LatLng _mapCenter = const LatLng(18.5912, 73.7389);
  final LocationService _locationService = LocationService();
  bool _isLoadingLiveRequests = false;
  String? _actioningRequestId;
  bool _isClearingAll = false;
  bool _blinkOn = true;
  Timer? _blinkTimer;
  Timer? _livePollTimer;
  final Set<String> _approvedRequestIds = <String>{};
  final Set<String> _shownSuccessRequestIds = <String>{};
  final Set<String> _seenRequestIds = <String>{};
  final Set<String> _knownPendingRequestIds = <String>{};
  bool _hasInitializedPendingSnapshot = false;
  bool _hasInitializedConfirmedSnapshot = false;
  final DateTime _sessionStartedAt = DateTime.now();
  DateTime? _lastHistoryConfirmedAt;
  DateTime? _lastSummaryRefreshedAt;
  DateTime? _lastProfileRefreshedAt;
  bool _isSummaryLoading = false;
  bool _isFetchingLiveRequests = false;
  int _todayConfirmedCount = 0;
  int _totalConfirmedCount = 0;
  int _totalConfirmedAmount = 0;
  bool _isPollingActive = false;
  StreamSubscription<String?>? _notificationTapSubscription;

  List<AgentLiveRequest> _liveRequests = const <AgentLiveRequest>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastHistoryConfirmedAt = _sessionStartedAt;
    _startIndicatorBlink();
    _loadAgentProfile();
    _loadInitialMapLocation();
    _loadLiveRequests();
    _loadTransactionSummary();
    _startLiveRequestPolling();
    _notificationTapSubscription = LocalNotificationService
        .instance
        .onNotificationTap
        .listen((payload) {
          if (!mounted) return;
          if (payload == 'open_live_requests') {
            _openLiveRequestNotifications();
          }
        });

    if (widget.openLiveRequestsOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openLiveRequestNotifications();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _stopLiveRequestPolling();
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLiveRequestPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopLiveRequestPolling();
    }
  }

  void _startLiveRequestPolling() {
    if (_isPollingActive) return;
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _loadLiveRequests(silent: true);
      _pollRecentConfirmedFromHistory();
      _refreshSummaryIfNeeded();
      _refreshProfileIfNeeded();
    });
    _isPollingActive = true;
  }

  void _stopLiveRequestPolling() {
    _livePollTimer?.cancel();
    _livePollTimer = null;
    _isPollingActive = false;
  }

  void _refreshSummaryIfNeeded() {
    if (_isSummaryLoading) return;
    final last = _lastSummaryRefreshedAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 15) return;
    _loadTransactionSummary();
  }

  void _refreshProfileIfNeeded() {
    final last = _lastProfileRefreshedAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 10) return;
    _lastProfileRefreshedAt = DateTime.now();
    _loadAgentProfile();
  }

  Future<void> _loadTransactionSummary() async {
    if (!mounted) return;
    _isSummaryLoading = true;
    try {
      final history = await AgentService.getTransactionHistory(limit: 20);
      if (!mounted) return;

      final confirmed = history
          .where((item) => _isConfirmedStatus(item.status))
          .toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int todayCount = 0;
      int totalCount = history.length;
      int totalAmount = 0;

      for (final item in history) {
        final ts = item.completedAt ?? item.updatedAt ?? item.createdAt;
        if (ts == null) continue;
        final itemDay = DateTime(ts.year, ts.month, ts.day);
        if (itemDay == today) {
          todayCount += 1;
        }
      }

      for (final item in confirmed) {
        totalAmount += item.agentReceived;
      }

      if (!mounted) return;
      setState(() {
        _todayConfirmedCount = todayCount;
        _totalConfirmedCount = totalCount;
        _totalConfirmedAmount = totalAmount;
        _lastSummaryRefreshedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastSummaryRefreshedAt = DateTime.now();
      });
    } finally {
      _isSummaryLoading = false;
    }
  }

  Future<void> _pollRecentConfirmedFromHistory() async {
    try {
      final history = await AgentService.getTransactionHistory(limit: 20);
      if (!mounted) return;

      final recentConfirmed = history.where((item) {
        if (!_isConfirmedStatus(item.status)) return false;
        if (_shownSuccessRequestIds.contains(item.id)) return false;
        if (!_seenRequestIds.contains(item.id)) return false;
        final confirmedAt =
            item.completedAt ?? item.updatedAt ?? item.createdAt;
        if (confirmedAt == null) return false;
        if (_lastHistoryConfirmedAt != null &&
            !confirmedAt.isAfter(_lastHistoryConfirmedAt!)) {
          return false;
        }
        return true;
      }).toList();

      DateTime latestConfirmedAt = _lastHistoryConfirmedAt ?? _sessionStartedAt;
      for (final item in recentConfirmed) {
        if (!_shownSuccessRequestIds.add(item.id)) continue;
        if (!mounted) return;
        final confirmedAt =
            item.completedAt ?? item.updatedAt ?? item.createdAt;
        if (confirmedAt != null && confirmedAt.isAfter(latestConfirmedAt)) {
          latestConfirmedAt = confirmedAt;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AgentTransactionSuccessScreen(
              userName: item.userName,
              amount: item.amount,
              agentCommission: item.agentCommission,
              totalReceived: item.agentReceived,
            ),
          ),
        );
      }

      _lastHistoryConfirmedAt = latestConfirmedAt;
    } catch (_) {
      // ignore transient history polling errors
    }
  }

  bool _isConfirmedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'confirmed' ||
        normalized == 'success' ||
        normalized == 'completed';
  }

  void _startIndicatorBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      setState(() => _blinkOn = !_blinkOn);
    });
  }

  Future<void> _loadInitialMapLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _mapCenter = LatLng(location.latitude, location.longitude);
      });
    } catch (_) {}
  }

  Future<void> _loadAgentProfile() async {
    final wasBanned = _isBanned;
    final wasVerified = _isVerified;
    try {
      final profile = await AgentService.getProfile();
      if (!mounted) return;
      setState(() {
        _agentName = profile.name;
        _cityName = _deriveCityState(profile.city, profile.address);
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
        _isBanned = profile.isBanned ?? false;
        _isVerified = profile.isVerified ?? false;
        _isOnline = profile.available ?? true;
        _averageRating = profile.averageRating;
        _ratingCount = profile.ratingCount;
      });

      await _handleBanStatusChange(wasBanned, _isBanned);
      await _handleVerifiedStatusChange(wasVerified, _isVerified);

      // Dev behavior: make logged-in agent available automatically.
      if (!_isBanned && (profile.available ?? false) == false) {
        await AgentService.patchAgentProfile({'available': true});
        if (mounted) {
          setState(() => _isOnline = true);
        }
      }
    } catch (_) {
      final cached = await AgentService.getCachedProfile();
      if (!mounted || cached == null) return;
      setState(() {
        _agentName = cached.name;
        _cityName = _deriveCityState(cached.city, cached.address);
        _profilePhotoBytes = _decodeProfileImage(cached.profileImage);
        _isBanned = cached.isBanned ?? false;
        _isVerified = cached.isVerified ?? false;
        _isOnline = cached.available ?? true;
        _averageRating = cached.averageRating;
        _ratingCount = cached.ratingCount;
      });

      await _handleBanStatusChange(wasBanned, _isBanned);
      await _handleVerifiedStatusChange(wasVerified, _isVerified);
    }
  }

  Future<void> _showBannedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.block, color: Color(0xffDC2626)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Account Suspended',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account is temporarily suspended.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Priority support is available for suspended accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                const Text(
                  'support@email.com',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showUnverifiedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.info, color: Color(0xffB45309)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verification Pending',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your agent account is not verified yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _notifyBannedStatus() async {
    if (_hasShownBanNotification) return;
    _hasShownBanNotification = true;
    _hasShownUnbanNotification = false;
    await LocalNotificationService.instance.showAgentStatusNotification(
      title: 'Account Suspended',
      message:
          'Your agent account has been suspended. Contact support@cashlyt.com for help.',
      payload: 'agent_banned',
    );
  }

  Future<void> _notifyUnbannedStatus() async {
    if (_hasShownUnbanNotification) return;
    _hasShownUnbanNotification = true;
    _hasShownBanNotification = false;
    await LocalNotificationService.instance.showAgentStatusNotification(
      title: 'Account Reactivated',
      message: 'Good news! Your account has been restored after review.',
      payload: 'agent_unbanned',
    );
  }

  Future<void> _notifyVerifiedStatus() async {
    if (_hasShownVerifiedNotification) return;
    _hasShownVerifiedNotification = true;
    await LocalNotificationService.instance.showAgentStatusNotification(
      title: 'Profile Verified',
      message:
          'Congratulations! Your profile has been successfully verified. You now have full access to all agent features.',
      payload: 'agent_verified',
    );
  }

  Future<void> _handleBanStatusChange(bool wasBanned, bool isBanned) async {
    if (wasBanned == isBanned) return;
    if (isBanned) {
      await _notifyBannedStatus();
    } else {
      await _notifyUnbannedStatus();
    }
  }

  Future<void> _handleVerifiedStatusChange(
    bool wasVerified,
    bool isVerified,
  ) async {
    if (wasVerified == isVerified) return;
    if (isVerified) {
      await _notifyVerifiedStatus();
    } else {
      _hasShownVerifiedNotification = false;
    }
  }

  Future<void> _loadLiveRequests({bool silent = false}) async {
    if (!mounted) return;
    if (_isFetchingLiveRequests) return;
    _isFetchingLiveRequests = true;
    if (!silent) {
      setState(() => _isLoadingLiveRequests = true);
    }
    try {
      final requests = await AgentService.getLiveRequests(limit: 30);
      if (!mounted) return;
      _seenRequestIds.addAll(requests.map((item) => item.id));

      final confirmed = requests
          .where((item) => item.status.toLowerCase() == 'confirmed')
          .toList();
      if (!_hasInitializedConfirmedSnapshot) {
        _shownSuccessRequestIds.addAll(confirmed.map((item) => item.id));
        _hasInitializedConfirmedSnapshot = true;
      } else {
        for (final item in confirmed) {
          if (_shownSuccessRequestIds.add(item.id)) {
            final confirmedAt =
                item.agentConfirmedAt ??
                item.userConfirmedAt ??
                item.approvedAt;
            if (confirmedAt != null &&
                confirmedAt.isBefore(_sessionStartedAt)) {
              continue;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AgentTransactionSuccessScreen(
                    userName: item.name,
                    amount: item.amount,
                    agentCommission: item.agentCommission,
                    totalReceived: item.agentReceived,
                  ),
                ),
              );
            });
          }
        }
      }

      final liveOnly = requests
          .where(
            (item) =>
                item.status.toLowerCase() == 'pending' ||
                item.status.toLowerCase() == 'approved',
          )
          .toList();

      final pendingLive = liveOnly
          .where((item) => item.status.toLowerCase() == 'pending')
          .toList();
      final pendingIds = pendingLive.map((item) => item.id).toSet();
      if (_hasInitializedPendingSnapshot) {
        final newPending = pendingLive.where(
          (item) => !_knownPendingRequestIds.contains(item.id),
        );
        for (final item in newPending) {
          await LocalNotificationService.instance
              .showIncomingTransactionRequest(requesterName: item.name);
        }
      } else {
        _hasInitializedPendingSnapshot = true;
      }
      _knownPendingRequestIds
        ..clear()
        ..addAll(pendingIds);

      final requestIds = liveOnly.map((item) => item.id).toSet();
      setState(() {
        _liveRequests = liveOnly;
        _approvedRequestIds.removeWhere((id) => !requestIds.contains(id));
      });
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Exception: ', '')
          .toLowerCase();
      if (message.contains('banned')) {
        final wasBanned = _isBanned;
        if (!_isBanned) {
          setState(() => _isBanned = true);
        }
        await _handleBanStatusChange(wasBanned, true);
        _stopLiveRequestPolling();
        if (!silent) {
          await _showBannedDialog();
        }
        return;
      }
      if (message.contains('not verified')) {
        final wasVerified = _isVerified;
        if (_isVerified) {
          setState(() => _isVerified = false);
        }
        await _handleVerifiedStatusChange(wasVerified, false);
        if (!silent) {
          await _showUnverifiedDialog();
        }
        return;
      }
      if (!silent) {
        setState(() => _liveRequests = const <AgentLiveRequest>[]);
      }
    } finally {
      _isFetchingLiveRequests = false;
      if (mounted && !silent) setState(() => _isLoadingLiveRequests = false);
    }
  }

  Future<void> _rejectRequest(AgentLiveRequest request) async {
    if (_isBanned) {
      await _showBannedDialog();
      return;
    }
    if (!_isVerified) {
      await _showUnverifiedDialog();
      return;
    }
    if (_actioningRequestId != null) return;
    setState(() => _actioningRequestId = request.id);
    try {
      await AgentService.rejectLiveRequest(request.id);
      if (!mounted) return;
      setState(() {
        _liveRequests = _liveRequests
            .where((item) => item.id != request.id)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request rejected for ${request.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _actioningRequestId = null);
    }
  }

  Future<void> _clearAllLiveRequests() async {
    if (_isClearingAll || _liveRequests.isEmpty) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Clear all live requests?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will remove all live requests from your list.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldClear != true) return;

    setState(() => _isClearingAll = true);
    try {
      await AgentService.clearAllRequests();
      if (!mounted) return;
      setState(() {
        _liveRequests = const <AgentLiveRequest>[];
        _approvedRequestIds.clear();
        _shownSuccessRequestIds.clear();
        _seenRequestIds.clear();
        _knownPendingRequestIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All live requests cleared.')),
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('not found')) {
        final requests = List<AgentLiveRequest>.from(_liveRequests);
        for (final request in requests) {
          try {
            if (request.status.toLowerCase() == 'approved') {
              await AgentService.archiveLiveRequest(request.id);
            } else if (request.status.toLowerCase() == 'pending') {
              await AgentService.rejectLiveRequest(request.id);
            }
          } catch (_) {}
        }

        if (!mounted) return;
        setState(() {
          _liveRequests = const <AgentLiveRequest>[];
          _approvedRequestIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All live requests cleared.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isClearingAll = false);
    }
  }

  Future<void> _approveRequestWithOtp(AgentLiveRequest request) async {
    if (_isBanned) {
      await _showBannedDialog();
      return;
    }
    if (!_isVerified) {
      await _showUnverifiedDialog();
      return;
    }
    if (_actioningRequestId != null) return;
    setState(() => _actioningRequestId = request.id);
    try {
      await AgentService.approveLiveRequest(requestId: request.id);
      if (!mounted) return;
      await _loadLiveRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request approved for ${request.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _actioningRequestId = null);
    }
  }

  Uint8List? _decodeProfileImage(String? imageValue) {
    if (imageValue == null || imageValue.trim().isEmpty) return null;
    final trimmed = imageValue.trim();
    final base64Part = trimmed.startsWith('data:image') && trimmed.contains(',')
        ? trimmed.substring(trimmed.indexOf(',') + 1)
        : trimmed;
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  String _deriveCityState(String? city, String? address) {
    final cityText = (city ?? '').trim();
    final parts = (address ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    String fallbackCity = '';
    for (final part in parts.reversed) {
      if (!RegExp(r'\d').hasMatch(part)) {
        fallbackCity = part;
        break;
      }
    }

    final effectiveCity = cityText.isNotEmpty ? cityText : fallbackCity;
    if (effectiveCity.isEmpty) return 'India';
    return '$effectiveCity, India';
  }

  String _requestTypeLabel(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'cash_to_upi' || normalized == 'cash to upi') {
      return 'Cash to UPI';
    }
    if (normalized == 'upi_to_cash' || normalized == 'upi to cash') {
      return 'UPI to Cash';
    }
    return rawType.trim().isEmpty ? 'Cash to UPI' : rawType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(builder: (_) => const AgentProfileScreen()),
                    )
                    .then((_) {
                  if (mounted) {
                    _loadAgentProfile();
                  }
                });
              },
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xffE0ECFF),
                backgroundImage: _profilePhotoBytes != null
                    ? MemoryImage(_profilePhotoBytes!)
                    : null,
                child: _profilePhotoBytes == null
                    ? const Icon(Icons.person, size: 16, color: Color(0xff2563EB))
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _agentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_isVerified) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffECFDF3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Color(0xff16A34A)),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _openAgentNotificationCenter,
              tooltip: 'Notifications',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none, color: Colors.black87, size: 22),
                  StreamBuilder<int>(
                    stream: LocalNotificationService.instance.onBadgeCount,
                    initialData: LocalNotificationService.instance.badgeCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count <= 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(
                              alpha: _blinkOn ? 1 : 0.7,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBanned) ...[
                _buildBannedBanner(),
                const SizedBox(height: 12),
              ],
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildTransactionSummary(),
              const SizedBox(height: 18),
              _buildLiveRequestsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xff2563EB),
          unselectedItemColor: const Color(0xff6B7280),
          iconSize: 22,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            setState(() => _currentIndex = index);

          if (index == 1) {
            _stopLiveRequestPolling();
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => NearbyMapScreen(
                      initialCenter: _mapCenter,
                      markers: {
                        Marker(
                          markerId: const MarkerId('current_location'),
                          position: _mapCenter,
                          infoWindow: const InfoWindow(title: 'Your Area'),
                        ),
                      },
                    ),
                  ),
                )
                .then((_) {
                  if (mounted) {
                    setState(() => _currentIndex = 0);
                    _startLiveRequestPolling();
                  }
                });
          } else if (index == 2) {
            _stopLiveRequestPolling();
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const AgentTransactionsScreen(),
                  ),
                )
                .then((_) {
                  if (mounted) {
                    setState(() => _currentIndex = 0);
                    _startLiveRequestPolling();
                  }
                });
          } else if (index == 3) {
            _stopLiveRequestPolling();
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const AgentProfileScreen()),
                )
                .then((_) {
                  if (mounted) {
                    setState(() => _currentIndex = 0);
                    _startLiveRequestPolling();
                    _loadAgentProfile();
                  }
                });
          }
        },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCenteredOnlineToggle({bool inHero = false}) {
    if (_isBanned) {
      return GestureDetector(
        onTap: _showBannedDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xffFDECEC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffF7B6B6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, color: Colors.red, size: 16),
              SizedBox(width: 6),
              Text(
                'Banned',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusColor = _isOnline
      ? (inHero ? const Color(0xffBBF7D0) : const Color(0xff16A34A))
      : const Color(0xff9CA3AF);
    final statusText = _isOnline ? 'Online' : 'Offline';
    final maxToggleWidth = MediaQuery.of(context).size.width * 0.35;
    final textColor = inHero ? Colors.white : Colors.black87;
    final borderColor = inHero
      ? Colors.white.withValues(alpha: 0.35)
      : const Color(0xFFDCE6FF);
    final backgroundColor = inHero ? Colors.white.withValues(alpha: 0.12) : Colors.white;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxToggleWidth.clamp(150.0, 210.0)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.86,
              child: Switch(
                value: _isOnline,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) async {
                  setState(() => _isOnline = value);
                  try {
                    await AgentService.patchAgentProfile({'available': value});
                  } catch (_) {
                    if (!mounted) return;
                    setState(() => _isOnline = !value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAgentNotificationCenter() {
    LocalNotificationService.instance.markAllSeen();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffEAF0FF), Color(0xffF6FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffE6EBF5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_outlined, color: Color(0xff2563EB)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            LocalNotificationService.instance.clearAllNotifications(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xff2563EB),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<LocalNotificationItem>>(
                  stream: LocalNotificationService.instance.onNotificationList,
                  initialData:
                      LocalNotificationService.instance.activeNotifications,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No notifications yet')),
                      );
                    }
                    return Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(item.message),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              if (item.payload == 'open_live_requests') {
                                _openLiveRequestNotifications();
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3559C7),
            Color(0xFF4B7CF0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3559C7).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                backgroundImage: _profilePhotoBytes != null
                    ? MemoryImage(_profilePhotoBytes!)
                    : null,
                child: _profilePhotoBytes == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _agentName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _cityName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildCenteredOnlineToggle(inHero: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xffFFD166), size: 18),
              const SizedBox(width: 4),
              Text(
                _averageRating == null
                    ? 'New'
                    : '${_averageRating!.toStringAsFixed(1)} ($_ratingCount)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannedBanner() {
    return InkWell(
      onTap: _showBannedDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffFFF1F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffF7B6B6)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You are banned',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLiveRequestNotifications() async {
    await _loadLiveRequests();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xffF5F7FB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live Request Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoadingLiveRequests
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _openLiveRequestNotifications();
                            },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingLiveRequests)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_liveRequests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No new live request right now.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'You have a request for exchange money. Kindly refresh the live transaction.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _liveRequests.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _liveRequests[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.name} • ${item.city.isEmpty ? 'City not available' : item.city}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${item.agentReceived}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Fee ₹${item.agentCommission}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Today\'s Requests',
                '$_todayConfirmedCount',
                Icons.today_rounded,
                const Color(0xFFEAF0FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Total Transactions',
                '$_totalConfirmedCount',
                Icons.receipt_long_outlined,
                const Color(0xFFE8F8EF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Collected Amount',
                '₹$_totalConfirmedAmount',
                Icons.account_balance_wallet_outlined,
                const Color(0xFFFFF3E8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color iconBg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECFA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF3559C7)),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRequestsSection() {
    final liveCount = _liveRequests.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: const Text(
                  'Live Transaction Requests',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(
                          alpha: _blinkOn ? 1 : 0.25,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$liveCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _isLoadingLiveRequests ? null : _loadLiveRequests,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    onPressed:
                        _isLoadingLiveRequests ||
                            _isClearingAll ||
                            _liveRequests.isEmpty
                        ? null
                        : _clearAllLiveRequests,
                    icon: _isClearingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear_all, size: 18),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Clear all',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingLiveRequests)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_liveRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No requests yet',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Stay online to receive requests',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveRequests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _requestCard(_liveRequests[index]),
            ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AgentTransactionsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View All Requests'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(AgentLiveRequest request) {
    final isApproved =
        request.status.toLowerCase() == 'approved' ||
        _approvedRequestIds.contains(request.id);
    final isBusy = _actioningRequestId == request.id;
    final approveButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF16A34A),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFA7DDB9),
      disabledForegroundColor: Colors.white70,
      minimumSize: const Size(double.infinity, 40),
      elevation: 0,
      splashFactory: InkRipple.splashFactory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
      ),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        return null;
      }),
    );

    final rejectButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(double.infinity, 40)),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return const Color(0xFF9CA3AF);
        return const Color(0xFF4B5563);
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return const Color(0xFFF6F7F9);
        return Colors.white;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: Color(0xFFD1D5DB));
        }
        return const BorderSide(color: Color(0xFFBFC7D8));
      }),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      splashFactory: InkRipple.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.black.withValues(alpha: 0.05);
        }
        return null;
      }),
    );

    return InkWell(
      onTap: () => _showRequestDetailsDialog(request),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '₹${request.amount}',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _requestTypeLabel(request.type),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isApproved) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFBCE3CA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Approved',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () => _approveRequestWithOtp(request),
                      style: approveButtonStyle,
                      child: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy ? null : () => _rejectRequest(request),
                      style: rejectButtonStyle,
                      child: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF9CA3AF),
                              ),
                            )
                          : const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRequestDetailsDialog(AgentLiveRequest request) async {
    if (!mounted) return;
    if (_isBanned) {
      await _showBannedDialog();
      return;
    }
    if (!_isVerified) {
      await _showUnverifiedDialog();
      return;
    }

    String otpValue = '';
    String? inlineError;
    bool isVerifying = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            void safeSetState(VoidCallback update) {
              if (dialogContext.mounted) {
                setLocalState(update);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Request Details',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'User Info',
                      child: Column(
                        children: [
                          _infoRowCompact('Name', request.name),
                          _infoRowCompact(
                            'Phone',
                            request.phone.isNotEmpty
                                ? request.phone
                                : 'Not available',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _sectionCard(
                      title: 'Transaction',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₹${request.amount}',
                                style: const TextStyle(
                                  color: Color(0xff16A34A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _infoRowCompact(
                            'Type',
                            _requestTypeLabel(request.type),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _sectionCard(
                      title: 'Location',
                      child: Column(
                        children: [
                          _infoRowCompact(
                            'City',
                            request.city.isNotEmpty
                                ? request.city
                                : 'Not available',
                          ),
                          _infoRowCompact(
                            'Address',
                            request.address.isNotEmpty
                                ? request.address
                                : 'Not available',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Your OTP',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            request.agentConfirmOtp.isEmpty
                                ? '----'
                                : request.agentConfirmOtp,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Color(0xff1D4ED8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter OTP',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      enabled: !isVerifying && request.agentConfirmedAt == null,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: (value) => otpValue = value.trim(),
                      decoration: InputDecoration(
                        hintText: '----',
                        counterText: '',
                        errorText: inlineError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xffFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isVerifying
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isVerifying ||
                                    request.status.toLowerCase() != 'approved' ||
                                    request.agentConfirmedAt != null
                                ? null
                                : () async {
                                    final otp = otpValue.trim();
                                    if (otp.length != 4) {
                                      safeSetState(
                                        () => inlineError =
                                            'Enter valid 4-digit OTP',
                                      );
                                      return;
                                    }

                                    safeSetState(() {
                                      inlineError = null;
                                      isVerifying = true;
                                    });

                                    if (mounted) {
                                      setState(() => _actioningRequestId = request.id);
                                    }
                                    try {
                                      if (request.approvedAt == null) {
                                        final agentOtp =
                                            await AgentService.verifyRequestOtp(
                                          requestId: request.id,
                                          otp: otp,
                                        );
                                        if (!mounted) return;
                                        await _loadLiveRequests();
                                        if (!mounted) return;
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (mounted && this.context.mounted) {
                                          await showDialog<void>(
                                            context: this.context,
                                            builder: (popupContext) {
                                              return Dialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: SingleChildScrollView(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 48,
                                                        height: 48,
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xffECFDF3),
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                        child: const Icon(
                                                          Icons.check_circle,
                                                          color: Color(0xff059669),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      const Text(
                                                        'OTP Verified',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Your OTP: ${agentOtp ?? 'Check details'}',
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(color: Colors.black54),
                                                      ),
                                                      const SizedBox(height: 14),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.of(popupContext).pop(),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(0xff16A34A),
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                          ),
                                                          child: const Text('OK'),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                        return;
                                      }

                                      final status =
                                          await AgentService.confirmWithUserOtp(
                                        transactionId: request.id,
                                        otp: otp,
                                      );
                                      if (!mounted) return;
                                      await _loadLiveRequests();
                                      if (!mounted) return;
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      if (status == 'confirmed') {
                                        if (mounted && this.context.mounted) {
                                          Navigator.of(this.context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AgentTransactionSuccessScreen(
                                                userName: request.name,
                                                amount: request.amount,
                                                agentCommission:
                                                    request.agentCommission,
                                                totalReceived:
                                                    request.agentReceived,
                                              ),
                                            ),
                                          );
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Transaction successful.',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted && this.context.mounted) {
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'User OTP verified. Please share your OTP to user.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (error) {
                                      if (!mounted) return;
                                      safeSetState(() {
                                        inlineError = error
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                      });
                                    } finally {
                                      if (mounted) {
                                        setState(() => _actioningRequestId = null);
                                      }
                                      safeSetState(() => isVerifying = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isVerifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verify OTP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE6EBF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoRowCompact(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
