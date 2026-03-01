import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:async';

import '../../services/agent_service.dart';
import '../../services/location_service.dart';
import 'agent_profile_screen.dart';
import 'agent_transaction_success_screen.dart';
import 'agent_transactions_screen.dart';
import '../shared/nearby_map_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
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
  bool _blinkOn = true;
  Timer? _blinkTimer;
  final Set<String> _approvedRequestIds = <String>{};

  List<AgentLiveRequest> _liveRequests = const <AgentLiveRequest>[];

  @override
  void initState() {
    super.initState();
    _startIndicatorBlink();
    _loadAgentProfile();
    _loadInitialMapLocation();
    _loadLiveRequests();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
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

  Future<void> _loadLiveRequests() async {
    setState(() => _isLoadingLiveRequests = true);
    try {
      final requests = await AgentService.getLiveRequests(limit: 30);
      if (!mounted) return;
      final requestIds = requests.map((item) => item.id).toSet();
      setState(() {
        _liveRequests = requests;
        _approvedRequestIds.removeWhere((id) => !requestIds.contains(id));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveRequests = const <AgentLiveRequest>[]);
    } finally {
      if (mounted) setState(() => _isLoadingLiveRequests = false);
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

  Future<void> _approveRequestWithOtp(AgentLiveRequest request) async {
    if (_actioningRequestId != null) return;
    setState(() => _actioningRequestId = request.id);
    try {
      await AgentService.approveLiveRequest(request.id);
      if (!mounted) return;
      setState(() {
        _liveRequests = _liveRequests
            .map((item) => item.id == request.id ? item.copyWith(status: 'approved') : item)
            .toList();
      });
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentProfileScreen()),
              );
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
            onPressed: _openLiveRequestNotifications,
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: Colors.black87),
                if (_liveRequests.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: _blinkOn ? 1 : 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
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
              if (mounted) setState(() => _currentIndex = 0);
            });
          } else if (index == 2) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const AgentTransactionsScreen()),
                )
                .then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          } else if (index == 3) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(builder: (_) => const AgentProfileScreen()),
                )
                .then((_) {
              if (mounted) {
                setState(() => _currentIndex = 0);
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
            Expanded(child: _summaryCard('Today\'s Requests', '3')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Total Transactions', '48')),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Earnings', '₹2,350')),
          ],
        ),
        // TODO: Backend will fetch transaction summary and live requests
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
                Text(
                  '₹${request.amount}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
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

  Future<void> _showRequestDetailsDialog(AgentLiveRequest request) async {
    final otpController = TextEditingController();
    String? inlineError;
    bool isVerifying = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
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
                      'OTP Verification',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      enabled: !isVerifying,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter 4-digit OTP',
                        counterText: '',
                        errorText: inlineError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xffFAFAFA),
                      ),
                    ),
                    if (request.status.toLowerCase() != 'approved') ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Approve request first, then verify OTP.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
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
                            onPressed: isVerifying || request.status.toLowerCase() != 'approved'
                                ? null
                                : () async {
                                    final otp = otpController.text.trim();
                                    if (otp.length != 4) {
                                      setLocalState(() => inlineError = 'Enter valid 4-digit OTP');
                                      return;
                                    }

                                    setLocalState(() {
                                      inlineError = null;
                                      isVerifying = true;
                                    });

                                    setState(() => _actioningRequestId = request.id);
                                    try {
                                      await AgentService.verifyTransactionOtp(
                                        transactionId: request.id,
                                        otp: otp,
                                      );
                                      if (!mounted) return;
                                      setState(() {
                                        _approvedRequestIds.add(request.id);
                                        _liveRequests = _liveRequests.where((item) => item.id != request.id).toList();
                                      });
                                      Navigator.of(dialogContext).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AgentTransactionSuccessScreen(
                                            userName: request.name,
                                            amount: request.amount,
                                          ),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Transaction successful. Check Transactions tab.')),
                                      );
                                    } catch (error) {
                                      if (!mounted) return;
                                      setLocalState(() {
                                        inlineError = error.toString().replaceFirst('Exception: ', '');
                                      });
                                    } finally {
                                      if (mounted) setState(() => _actioningRequestId = null);
                                      setLocalState(() => isVerifying = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: isVerifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

    otpController.dispose();
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
