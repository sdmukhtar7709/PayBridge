import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../upi_to_cash_screen.dart';
import '../cash_to_upi_screen.dart';
import '../available_agents/available_agents_screen.dart';
import '../profile/user_profile_screen.dart';
import '../transactions/my_requests_screen.dart';
import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/available_agents_context_store.dart';
import '../../../services/profile_photo_service.dart';
import '../../../services/user_service.dart';
import '../../../services/location_service.dart';
import '../../../services/local_notification_service.dart';
import '../../shared/nearby_map_screen.dart';

part 'user_home_widgets.dart';

/// =======================================================
/// USER HOME SCREEN
/// Main dashboard for users
/// =======================================================
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  static final String _apiBaseUrl = ApiConfig.baseUrl;

  int _currentIndex = 0; // Track selected tab locally.
  bool _useCurrentLocation = false;
  String _cityLabel = 'Wagholi, Pune';
  String _profileFirstName = 'User';
  File? _photoFile;
  Uint8List? _profilePhotoBytes;
  bool _isFetchingLocation = false;
  LatLng _mapCenter = const LatLng(18.5912, 73.7389);
  GoogleMapController? _mapController;
  final Set<Marker> _mapMarkers = {};
  List<_HomeAgentSummary> _nearbyAgents = const [];
  bool _isLoadingAgents = false;
  String? _agentsError;
  final Map<String, String> _requestStatusByAgentId = {};
  final ProfilePhotoService _photoService = ProfilePhotoService();
  final UserService _userService = UserService();
  final LocationService _locationService = LocationService();
  Timer? _requestStatusPollTimer;
  final Map<String, String> _knownRequestStatusById = {};
  bool _isPollingRequestStatuses = false;
  bool _hasInitializedRequestStatusSnapshot = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadProfileName();
    _loadInitialMapLocation();
    _startRequestStatusPolling();
    _fetchNearbyAgents();
  }

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyMapScreen(
          initialCenter: _mapCenter,
          markers: _mapMarkers,
          autoLoadNearby: true,
        ),
      ),
    );
  }

  Future<void> _openAvailableAgentsFromHome() async {
    final city = _cityLabel.split(',').first.trim();
    await Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AvailableAgentsScreen(
              city: city.isEmpty ? 'your area' : city,
              latitude: _mapCenter.latitude,
              longitude: _mapCenter.longitude,
              radiusKm: 5.0,
              transactionType: 'UPI → Cash',
              amount: '1000',
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _currentIndex = 0);
        });
  }

  @override
  void dispose() {
    _requestStatusPollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startRequestStatusPolling() {
    _requestStatusPollTimer?.cancel();
    _pollUserRequestStatuses();
    _requestStatusPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollUserRequestStatuses();
    });
  }

  Future<void> _pollUserRequestStatuses() async {
    if (_isPollingRequestStatuses) return;
    _isPollingRequestStatuses = true;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/transactions/requests?limit=100'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return;
      final items = body['items'];
      if (items is! List) return;

      if (!_hasInitializedRequestStatusSnapshot) {
        for (final raw in items.whereType<Map<String, dynamic>>()) {
          final id = (raw['id'] ?? '').toString().trim();
          if (id.isEmpty) continue;
          final status = (raw['status'] ?? '').toString().trim().toLowerCase();
          if (status.isEmpty) continue;
          _knownRequestStatusById[id] = status;
        }
        _hasInitializedRequestStatusSnapshot = true;
        return;
      }

      bool requestMapChanged = false;
      final nextStatusByAgent = <String, String>{};
      for (final raw in items.whereType<Map<String, dynamic>>()) {
        final id = (raw['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final status = (raw['status'] ?? '').toString().trim().toLowerCase();
        if (status.isEmpty) continue;

        final agent = raw['agent'] is Map<String, dynamic>
            ? raw['agent'] as Map<String, dynamic>
            : <String, dynamic>{};
        final agentId = (raw['agentId'] ?? '').toString().trim().isNotEmpty
            ? (raw['agentId'] ?? '').toString().trim()
            : (agent['id'] ?? '').toString().trim();
        if (agentId.isNotEmpty) {
          nextStatusByAgent[agentId] = status;
        }

        final previous = _knownRequestStatusById[id];
        _knownRequestStatusById[id] = status;

        if (previous == status) continue;
        if (!_isNotifiableStatus(status)) continue;

        final user = agent['user'] is Map<String, dynamic>
            ? agent['user'] as Map<String, dynamic>
            : <String, dynamic>{};
        final agentName = (user['name'] ?? 'Agent').toString();

        await LocalNotificationService.instance.showUserStatusNotification(
          title: _statusTitle(status),
          message: _statusMessage(status, agentName),
          payload: 'user_request:$id',
        );
      }

      if (!mapEquals(nextStatusByAgent, _requestStatusByAgentId)) {
        _requestStatusByAgentId
          ..clear()
          ..addAll(nextStatusByAgent);
        requestMapChanged = true;
      }

      if (requestMapChanged && mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore transient polling/network errors.
    } finally {
      _isPollingRequestStatuses = false;
    }
  }

  bool _isNotifiableStatus(String status) {
    return status == 'approved' ||
        status == 'rejected' ||
        status == 'cancelled' ||
        status == 'confirmed';
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Request Approved';
      case 'rejected':
        return 'Request Rejected';
      case 'cancelled':
        return 'Request Cancelled';
      case 'confirmed':
        return 'Transaction Completed';
      default:
        return 'Request Update';
    }
  }

  String _statusMessage(String status, String agentName) {
    switch (status) {
      case 'approved':
        return '$agentName approved your request. Please see details.';
      case 'rejected':
        return '$agentName rejected your request.';
      case 'cancelled':
        return 'Your request has been cancelled.';
      case 'confirmed':
        return 'Your transaction with $agentName is completed.';
      default:
        return 'Your request status has changed.';
    }
  }

  Future<void> _loadInitialMapLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      _updateMapLocation(location);
    } catch (_) {
      // Keep default map center if initial GPS fetch fails.
    }
  }

  void _updateMapLocation(AppLocation location) {
    final nextCenter = LatLng(location.latitude, location.longitude);
    setState(() {
      _mapCenter = nextCenter;
      _mapMarkers.clear();
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(nextCenter, 14));
    _fetchNearbyAgents(silent: true);
  }

  Future<void> _applyCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      try {
        await _userService.updateProfile({
          'address': location.address,
          'city': location.city,
        });
      } catch (_) {
        // Ignore profile persistence errors here; location UX should still work.
      }
      if (!mounted) return;
      setState(() {
        _useCurrentLocation = true;
        _cityLabel = location.city;
      });
      _updateMapLocation(location);
    } catch (error) {
      if (!mounted) return;
      setState(() => _useCurrentLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _loadPhoto() async {
    final file = await _photoService.loadPhotoFile();
    if (mounted) {
      setState(() => _photoFile = file);
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

  Future<void> _loadProfileName() async {
    try {
      final profile = await _userService.getProfile();
      if (!mounted) return;
      setState(() {
        _profileFirstName = _extractFirstName(profile.displayName);
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
        if (profile.city != null && profile.city!.trim().isNotEmpty) {
          _cityLabel = profile.city!.trim();
        }
      });
    } catch (_) {
      final cached = await _userService.getCachedProfile();
      if (!mounted || cached == null) return;
      setState(() {
        _profileFirstName = _extractFirstName(cached.displayName);
        _profilePhotoBytes = _decodeProfileImage(cached.profileImage);
        if (cached.city != null && cached.city!.trim().isNotEmpty) {
          _cityLabel = cached.city!.trim();
        }
      });
    }
  }

  String _extractFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'User';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _setCurrentLocationEnabled(bool value) {
    setState(() => _useCurrentLocation = value);
    _fetchNearbyAgents(silent: true);
  }

  Future<void> _fetchNearbyAgents({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingAgents = true;
        _agentsError = null;
      });
    }

    try {
      final queryParams = <String, String>{};
      final city = _cityLabel.split(',').first.trim();
      if (city.isNotEmpty) {
        queryParams['city'] = city;
      }
      if (_mapCenter.latitude != 0 && _mapCenter.longitude != 0) {
        queryParams['lat'] = _mapCenter.latitude.toString();
        queryParams['lng'] = _mapCenter.longitude.toString();
        queryParams['radius'] = '5.0';
      }

      final uri = Uri.parse('$_apiBaseUrl/agents/nearby').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final list = decoded is List
          ? decoded
          : (decoded['agents'] as List? ?? []);

      final agents = list
          .whereType<Map<String, dynamic>>()
          .map(_HomeAgentSummary.fromJson)
          .where((agent) =>
              !agent.isBanned && agent.isVerified && agent.available)
          .toList();

      if (!mounted) return;
      setState(() {
        _nearbyAgents = agents;
        _agentsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agentsError = e.toString().replaceFirst('Exception: ', '');
        _nearbyAgents = const [];
      });
    } finally {
      if (mounted && !silent) setState(() => _isLoadingAgents = false);
    }
  }

  double _distanceKmTo(_HomeAgentSummary agent) {
    if (agent.latitude == null || agent.longitude == null) return 0;
    const radius = 6371.0;
    final dLat = _deg2rad(agent.latitude! - _mapCenter.latitude);
    final dLon = _deg2rad(agent.longitude! - _mapCenter.longitude);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(_mapCenter.latitude)) *
            cos(_deg2rad(agent.latitude!)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildHeroCard(),
              const SizedBox(height: 20),
              _buildActionRow(),
              const SizedBox(height: 18),
              _buildTrustRow(context),
              const SizedBox(height: 18),
              _buildAgents(context),
              const SizedBox(height: 18),
              _buildMapPreview(),
              const SizedBox(height: 14),
              _buildSos(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
          selectedItemColor: const Color(0xff2563EB),
          unselectedItemColor: const Color(0xff6B7280),
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          iconSize: 22,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
          if (index == 1) {
            _openFullMap();
            return;
          }

          if (index == 2) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                )
                .then((_) {
                  if (mounted) setState(() => _currentIndex = 0);
                });
            return;
          }

          if (index == 3) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                )
                .then((_) {
                  if (mounted) {
                    _loadPhoto();
                    _loadProfileName();
                    setState(() => _currentIndex = 0);
                  }
                });
            return;
          }

          if (index == 4) {
            _openAvailableAgentsFromHome();
            return;
          }

          setState(() => _currentIndex = index);
        },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_2_outlined),
              label: 'Agents',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAgentSummary {
  final String id;
  final String name;
  final String locationName;
  final String city;
  final bool isVerified;
  final bool available;
  final bool isBanned;
  final int ratingSum;
  final int ratingCount;
  final double? latitude;
  final double? longitude;
  final Uint8List? profilePhotoBytes;

  const _HomeAgentSummary({
    required this.id,
    required this.name,
    required this.locationName,
    required this.city,
    required this.isVerified,
    required this.available,
    required this.isBanned,
    required this.ratingSum,
    required this.ratingCount,
    this.latitude,
    this.longitude,
    this.profilePhotoBytes,
  });

  double? get averageRating {
    if (ratingCount <= 0) return null;
    return ratingSum / ratingCount;
  }

  factory _HomeAgentSummary.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name = (user['name'] ?? json['name'] ?? 'Agent').toString();
    final locationName = (json['locationName'] ?? '').toString();
    final city = (json['city'] ?? '').toString();
    final isVerified = (json['isVerified'] as bool?) ?? false;
    final available = (json['available'] as bool?) ?? false;
    final isBanned = (json['isBanned'] as bool?) ?? false;
    final ratingSum = int.tryParse((json['ratingSum'] ?? '0').toString()) ?? 0;
    final ratingCount = int.tryParse((json['ratingCount'] ?? '0').toString()) ?? 0;
    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);

    final rawPhoto = (user['profileImage'] ?? json['profileImage'] ?? '').toString();
    Uint8List? photoBytes;
    if (rawPhoto.trim().isNotEmpty) {
      final trimmed = rawPhoto.trim();
      final base64str = trimmed.startsWith('data:image') && trimmed.contains(',')
          ? trimmed.substring(trimmed.indexOf(',') + 1)
          : trimmed;
      try {
        photoBytes = base64Decode(base64str);
      } catch (_) {}
    }

    return _HomeAgentSummary(
      id: (json['id'] ?? '').toString(),
      name: name,
      locationName: locationName,
      city: city,
      isVerified: isVerified,
      available: available,
      isBanned: isBanned,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      latitude: latitude,
      longitude: longitude,
      profilePhotoBytes: photoBytes,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
