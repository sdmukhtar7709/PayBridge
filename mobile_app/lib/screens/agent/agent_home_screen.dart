import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:async';

import '../../services/agent_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/location_service.dart';
import 'agent_profile_screen.dart';
import 'agent_transaction_success_screen.dart';
import 'agent_transactions_screen.dart';
import '../shared/nearby_map_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  final bool openLiveRequestsOnLoad;

  const AgentHomeScreen({super.key, this.openLiveRequestsOnLoad = false});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> with WidgetsBindingObserver {
  bool _isOnline = true;
  int _currentIndex = 0;

  String _shopName = 'Agent Shop';
  String _agentName = 'Agent';
  String _cityName = 'Your City';
  Uint8List? _profilePhotoBytes;
  final double _rating = 4.6; // TODO: Backend will calculate agent rating from user feedback

  LatLng _mapCenter = const LatLng(18.5912, 73.7389);
  final LocationService _locationService = LocationService();
  bool _isLoadingLiveRequests = false;
  String? _actioningRequestId;
  String? _archivingRequestId;
  bool _isClearingAll = false;
  bool _blinkOn = true;
  Timer? _blinkTimer;
  Timer? _livePollTimer;
  final Set<String> _approvedRequestIds = <String>{};
  final Set<String> _shownSuccessRequestIds = <String>{};
  final Set<String> _seenRequestIds = <String>{};
  final Set<String> _knownPendingRequestIds = <String>{};
  final DateTime _sessionStartedAt = DateTime.now();
  DateTime? _lastHistoryConfirmedAt;
  DateTime? _lastSummaryRefreshedAt;
  bool _isSummaryLoading = false;
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
    _notificationTapSubscription =
        LocalNotificationService.instance.onNotificationTap.listen((payload) {
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
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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

  Future<void> _loadTransactionSummary() async {
    if (!mounted) return;
    _isSummaryLoading = true;
    try {
      final history = await AgentService.getTransactionHistory(limit: 20);
      if (!mounted) return;

      final confirmed = history.where((item) => _isConfirmedStatus(item.status)).toList();
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
        totalAmount += item.amount;
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
        final confirmedAt = item.completedAt ?? item.updatedAt ?? item.createdAt;
        if (confirmedAt == null) return false;
        if (_lastHistoryConfirmedAt != null && !confirmedAt.isAfter(_lastHistoryConfirmedAt!)) return false;
        return true;
      }).toList();

      DateTime latestConfirmedAt = _lastHistoryConfirmedAt ?? _sessionStartedAt;
      for (final item in recentConfirmed) {
        if (!_shownSuccessRequestIds.add(item.id)) continue;
        if (!mounted) return;
        final confirmedAt = item.completedAt ?? item.updatedAt ?? item.createdAt;
        if (confirmedAt != null && confirmedAt.isAfter(latestConfirmedAt)) {
          latestConfirmedAt = confirmedAt;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AgentTransactionSuccessScreen(
              userName: item.userName,
              amount: item.amount,
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
    return normalized == 'confirmed' || normalized == 'success' || normalized == 'completed';
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
    try {
      final profile = await AgentService.getProfile();
      if (!mounted) return;
      setState(() {
        _agentName = profile.name;
        _shopName = (profile.locationName ?? '').trim().isEmpty
            ? 'Agent Shop'
            : profile.locationName!.trim();
        _cityName = _deriveCity(profile.address);
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
        _isOnline = profile.available ?? true;
      });

      // Dev behavior: make logged-in agent available automatically.
      if ((profile.available ?? false) == false) {
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
        _shopName = (cached.locationName ?? '').trim().isEmpty
            ? 'Agent Shop'
            : cached.locationName!.trim();
        _cityName = _deriveCity(cached.address);
        _profilePhotoBytes = _decodeProfileImage(cached.profileImage);
        _isOnline = cached.available ?? true;
      });
    }
  }

  Future<void> _loadLiveRequests({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoadingLiveRequests = true);
    }
    try {
      final requests = await AgentService.getLiveRequests(limit: 30);
      if (!mounted) return;
      _seenRequestIds.addAll(requests.map((item) => item.id));

      final confirmed = requests.where((item) => item.status.toLowerCase() == 'confirmed').toList();
      for (final item in confirmed) {
        if (_shownSuccessRequestIds.add(item.id)) {
          final confirmedAt = item.agentConfirmedAt ?? item.userConfirmedAt ?? item.approvedAt;
          if (confirmedAt != null && confirmedAt.isBefore(_sessionStartedAt)) {
            continue;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AgentTransactionSuccessScreen(
                  userName: item.name,
                  amount: item.amount,
                ),
              ),
            );
          });
        }
      }

      final liveOnly = requests
          .where((item) => item.status.toLowerCase() == 'pending' || item.status.toLowerCase() == 'approved')
          .toList();

      final pendingLive = liveOnly.where((item) => item.status.toLowerCase() == 'pending').toList();
      final pendingIds = pendingLive.map((item) => item.id).toSet();
      final newPending = pendingLive.where((item) => !_knownPendingRequestIds.contains(item.id));
      for (final item in newPending) {
        await LocalNotificationService.instance.showIncomingTransactionRequest(
          requesterName: item.name,
        );
      }
      _knownPendingRequestIds
        ..clear()
        ..addAll(pendingIds);

      final requestIds = liveOnly.map((item) => item.id).toSet();
      setState(() {
        _liveRequests = liveOnly;
        _approvedRequestIds.removeWhere((id) => !requestIds.contains(id));
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _liveRequests = const <AgentLiveRequest>[]);
      }
    } finally {
      if (mounted && !silent) setState(() => _isLoadingLiveRequests = false);
    }
  }

  Future<void> _rejectRequest(AgentLiveRequest request) async {
    if (_actioningRequestId != null) return;
    setState(() => _actioningRequestId = request.id);
    try {
      await AgentService.rejectLiveRequest(request.id);
      if (!mounted) return;
      setState(() {
        _liveRequests = _liveRequests.where((item) => item.id != request.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request rejected for ${request.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
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
        return AlertDialog(
          title: const Text('Clear all live requests?'),
          content: const Text('This will remove all live requests from your list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear All'),
            ),
          ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingAll = false);
    }
  }

  Future<void> _approveRequestWithOtp(AgentLiveRequest request) async {
    if (_actioningRequestId != null) return;
    setState(() => _actioningRequestId = request.id);
    try {
      await AgentService.approveLiveRequest(requestId: request.id);
      if (!mounted) return;
      await _loadLiveRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request approved for ${request.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actioningRequestId = null);
    }
  }

  Future<void> _archiveApprovedRequest(AgentLiveRequest request) async {
    if (_archivingRequestId != null) return;
    setState(() => _archivingRequestId = request.id);
    try {
      await AgentService.archiveLiveRequest(request.id);
      if (!mounted) return;
      setState(() {
        _liveRequests = _liveRequests.where((item) => item.id != request.id).toList();
        _approvedRequestIds.remove(request.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request cleared for ${request.name}')),
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('not found')) {
        if (!mounted) return;
        setState(() {
          _liveRequests = _liveRequests.where((item) => item.id != request.id).toList();
          _approvedRequestIds.remove(request.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request cleared for ${request.name}')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _archivingRequestId = null);
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

  String _deriveCity(String? address) {
    if (address == null || address.trim().isEmpty) return 'Your City';
    final parts = address.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : address.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        centerTitle: true,
        leadingWidth: 170,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              _stopLiveRequestPolling();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentProfileScreen()),
              ).then((_) {
                if (mounted) {
                  _startLiveRequestPolling();
                  _loadAgentProfile();
                }
              });
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  backgroundImage: _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                  child: _profilePhotoBytes == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _agentName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        title: _buildCenteredOnlineToggle(),
        actions: [
          IconButton(
            onPressed: _openAgentNotificationCenter,
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: Colors.black87),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: _blinkOn ? 1 : 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildTransactionSummary(),
              const SizedBox(height: 18),
              _buildLiveRequestsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
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
                  MaterialPageRoute(builder: (_) => const AgentTransactionsScreen()),
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildCenteredOnlineToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xffEEF4FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Switch(
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
        ],
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
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () => LocalNotificationService.instance.clearAllNotifications(),
                  child: const Text('Clear All'),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<LocalNotificationItem>>(
                  stream: LocalNotificationService.instance.onNotificationList,
                  initialData: LocalNotificationService.instance.activeNotifications,
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
                        separatorBuilder: (_, __) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final displayShop = _shopName.isNotEmpty ? _shopName : 'Independent Agent';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 186, 212, 250), Color.fromARGB(255, 238, 177, 140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayShop,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _agentName,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 18),
              const SizedBox(width: 4),
              Text(_cityName, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text('$_rating • Demo rating'),
            ],
          ),
          // TODO: Backend will calculate agent rating from user feedback
        ],
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
                    const Icon(Icons.notifications_active, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live Request Notifications',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '₹${item.amount}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
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
            Expanded(child: _summaryCard('Today\'s Requests', '$_todayConfirmedCount')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Total Transactions', '$_totalConfirmedCount')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Earnings', '₹$_totalConfirmedAmount')),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLiveRequestsSection() {
    final liveCount = _liveRequests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Live Transaction Requests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: _blinkOn ? 1 : 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$liveCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: _isLoadingLiveRequests ? null : _loadLiveRequests,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _isLoadingLiveRequests || _isClearingAll || _liveRequests.isEmpty
                  ? null
                  : _clearAllLiveRequests,
              icon: _isClearingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.clear_all, size: 20),
              tooltip: 'Clear all',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingLiveRequests)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_liveRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No live requests yet',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ..._liveRequests.map(_requestCard),
      ],
    );
  }

  Widget _requestCard(AgentLiveRequest request) {
    final isApproved = request.status.toLowerCase() == 'approved' || _approvedRequestIds.contains(request.id);
    return InkWell(
      onTap: () => _showRequestDetailsDialog(request),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
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
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xffeaf2ff),
                  child: Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.city.isNotEmpty ? request.city : 'City not available',
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${request.amount}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (isApproved)
                      IconButton(
                        onPressed: _archivingRequestId == request.id
                            ? null
                            : () => _confirmArchiveDialog(request),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear approved request',
                        padding: const EdgeInsets.only(left: 6),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.type,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.touch_app, size: 16, color: Colors.black45),
                const SizedBox(width: 4),
                const Text(
                  'Tap for details',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: isApproved
                      ? Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xffF4F4F4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffE7E7E7)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.black54, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Approved',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _actioningRequestId == request.id
                              ? null
                              : () => _approveRequestWithOtp(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(double.infinity, 42),
                          ),
                          child: _actioningRequestId == request.id
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
                    onPressed: _actioningRequestId == request.id || isApproved
                        ? null
                        : () => _rejectRequest(request),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42)),
                    child: _actioningRequestId == request.id
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchiveDialog(AgentLiveRequest request) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear approved request?'),
          content: const Text(
            'This will remove the approved request from your live list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldArchive == true) {
      await _archiveApprovedRequest(request);
    }
  }

  Future<void> _showRequestDetailsDialog(AgentLiveRequest request) async {
    if (!mounted) return;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.request_page, color: Colors.blue),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'User Request Details',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoTile('Full Name', request.name),
                    _infoTile('Mobile', request.phone.isNotEmpty ? request.phone : 'Not available'),
                    _infoTile('Email', request.email.isNotEmpty ? request.email : 'Not available'),
                    _infoTile('Address', request.address.isNotEmpty ? request.address : 'Not available'),
                    _infoTile('City', request.city.isNotEmpty ? request.city : 'Not available'),
                    _infoTile('Amount', '₹${request.amount}'),
                    const SizedBox(height: 12),
                    const Text(
                      'OTP Confirmation',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (request.status.toLowerCase() != 'approved') ...[
                      const Text(
                        'Approve request first. Then verify the user OTP.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      if (request.agentConfirmedAt != null)
                        const Text(
                          'You have already verified user OTP.',
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      if (request.approvedAt != null)
                        const Text(
                          'Thank you for connecting. Please meet and do the transaction securely.',
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        )
                      else
                        const Text(
                          'Verify user OTP to confirm you met.',
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 6),
                      if (request.approvedAt != null)
                        Text(
                          'Your OTP: ${request.agentConfirmOtp.isEmpty ? 'Pending' : request.agentConfirmOtp}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        request.approvedAt != null
                            ? 'Enter the OTP shown by the user to complete verification.'
                            : 'Enter the request OTP shown by the user.',
                        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
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
                          hintText: 'Enter user OTP',
                          counterText: '',
                          errorText: inlineError,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xffFAFAFA),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isVerifying ? null : () => Navigator.of(dialogContext).pop(),
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
                                      setLocalState(() => inlineError = 'Enter valid 4-digit OTP');
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
                                        final agentOtp = await AgentService.verifyRequestOtp(
                                          requestId: request.id,
                                          otp: otp,
                                        );
                                        if (!mounted) return;
                                        await _loadLiveRequests();
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        if (mounted) {
                                          await showDialog<void>(
                                            context: context,
                                            builder: (popupContext) {
                                              return AlertDialog(
                                                title: const Text('OTP Verified'),
                                                content: Text(
                                                  'Thank you for reaching out to each other. Now do your transaction securely without any inconvenience. All your transactions will be recorded end-to-end by the platform.\n\nYour OTP: ${agentOtp ?? 'Check details'}',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(popupContext).pop(),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                        return;
                                      }

                                      final status = await AgentService.confirmWithUserOtp(
                                        transactionId: request.id,
                                        otp: otp,
                                      );
                                      if (!mounted) return;
                                      await _loadLiveRequests();
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      if (status == 'confirmed') {
                                        if (mounted) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => AgentTransactionSuccessScreen(
                                                userName: request.name,
                                                amount: request.amount,
                                              ),
                                            ),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Transaction successful.')),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('User OTP verified. Please share your OTP to user.'),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (error) {
                                      if (!mounted) return;
                                      safeSetState(() {
                                        inlineError = error.toString().replaceFirst('Exception: ', '');
                                      });
                                    } finally {
                                      if (mounted) {
                                        setState(() => _actioningRequestId = null);
                                      }
                                      safeSetState(() => isVerifying = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: isVerifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(request.agentConfirmedAt != null ? 'Verified' : 'Verify OTP'),
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

  Widget _infoTile(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE8EEFA)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13.5),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
