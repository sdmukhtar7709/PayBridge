import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../services/location_service.dart';

class NearbyMapAgent {
  final String id;
  final String name;
  final String city;
  final String shopName;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  const NearbyMapAgent({
    required this.id,
    required this.name,
    required this.city,
    required this.shopName,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });
}

/// Full-screen map with satellite toggle, nearby ATMs/banks, and place search.
/// Shared between UserHomeScreen and AgentHomeScreen.
class NearbyMapScreen extends StatefulWidget {
  final LatLng initialCenter;
  final Set<Marker> markers;
  final bool autoLoadNearby;
  final List<NearbyMapAgent> agents;
  final double nearbyRadiusKm;

  const NearbyMapScreen({
    super.key,
    required this.initialCenter,
    required this.markers,
    this.autoLoadNearby = false,
    this.agents = const [],
    this.nearbyRadiusKm = 10,
  });

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  static final String _apiBaseUrl = ApiConfig.baseUrl;
  static const Color _userMarkerColor = Color(0xFF1E88E5);
  static const Color _atmMarkerColor = Color(0xFFEA580C);
  static const Color _bankMarkerColor = Color(0xFF16A34A);
  static const Color _agentMarkerColor = Color(0xFF7C3AED);

  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  bool _isSatelliteSelected = false;
  bool _isLoadingNearby = false;
  bool _isSearchingPlace = false;
  late LatLng _nearbySearchCenter;
  late Set<Marker> _mapMarkers;
  late List<NearbyMapAgent> _agentMarkersData;
  Set<Circle> _mapCircles = const {};

  int get _nearbyRadiusMeters => (widget.nearbyRadiusKm * 1000).round();

  @override
  void initState() {
    super.initState();
    _nearbySearchCenter = widget.initialCenter;
    _mapMarkers = Set<Marker>.from(widget.markers);
    _agentMarkersData = List<NearbyMapAgent>.from(widget.agents);
    _addAgentMarkers(_mapMarkers);
    if (widget.autoLoadNearby) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNearbyBanksAndAtms();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('Nearby Banks & ATMs', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter,
              zoom: 14,
            ),
            mapType: _isSatelliteSelected ? MapType.hybrid : MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: _mapMarkers,
            circles: _mapCircles,
            onMapCreated: (controller) {
              _controller = controller;
              _syncToCurrentLocationOnOpen();
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            child: ElevatedButton.icon(
              onPressed: _isLoadingNearby ? null : _loadNearbyBanksAndAtms,
              icon: const Icon(Icons.account_balance, size: 18),
              label: Text(_isLoadingNearby ? 'Loading...' : 'Nearby ATMs & Banks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xffE6EBF5)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Positioned(
            top: 68,
            left: 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffE6EBF5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchSpecificPlace(),
                      decoration: const InputDecoration(
                        hintText: 'Search specific place',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSearchingPlace ? null : _searchSpecificPlace,
                    child: Text(_isSearchingPlace ? '...' : 'Search'),
                  ),
                ],
              ),
            ),
          ),
          // Default / Satellite toggle pill
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xffE6EBF5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mapModeChip(
                    label: 'Default',
                    selected: !_isSatelliteSelected,
                    onTap: () => setState(() => _isSatelliteSelected = false),
                  ),
                  const SizedBox(width: 6),
                  _mapModeChip(
                    label: 'Satellite',
                    selected: _isSatelliteSelected,
                    onTap: () => setState(() => _isSatelliteSelected = true),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE6EBF5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MarkerLegendDot(color: _userMarkerColor, label: 'Your Location'),
                  SizedBox(height: 4),
                  _MarkerLegendDot(color: _atmMarkerColor, label: 'ATM'),
                  SizedBox(height: 4),
                  _MarkerLegendDot(color: _bankMarkerColor, label: 'Bank'),
                  SizedBox(height: 4),
                  _MarkerLegendDot(color: _agentMarkerColor, label: 'Agent'),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Center ${_fmt(_nearbySearchCenter.latitude)}, ${_fmt(_nearbySearchCenter.longitude)}\n'
                'Agents ${_agentMarkersData.length}  Markers ${_mapMarkers.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5E4AE3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _loadNearbyBanksAndAtms() async {
    setState(() => _isLoadingNearby = true);
    try {
      final center = await _resolveNearbySearchCenter();
      final nearbyAgents = await _fetchNearbyAgents(center);
      final uri = Uri.parse(
        '$_apiBaseUrl/maps/nearby-banks-atms?lat=${center.latitude}&lng=${center.longitude}&radius=$_nearbyRadiusMeters',
      );

      final response =
          await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          throw Exception(
              'Nearby places endpoint not found. Restart backend server.');
        }
        String message = 'Failed to load nearby places';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map<String, dynamic>) {
            message = (errBody['error'] as String?) ??
                (errBody['message'] as String?) ??
                message;
          }
        } catch (_) {}
        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);
      final results =
          (decoded is Map<String, dynamic> ? decoded['results'] : null)
                  as List<dynamic>? ??
              [];

      if (decoded is Map<String, dynamic>) {
        final statusCandidates = [decoded['atmStatus'], decoded['bankStatus']]
            .whereType<String>()
            .toList();
        final denied =
            statusCandidates.any((value) => value == 'REQUEST_DENIED');
        if (denied) {
          throw Exception(
              'Google Places request denied. Enable billing and Places API in Google Cloud.');
        }
      }

      final nextMarkers = <Marker>{};

      nextMarkers.add(
        Marker(
          markerId: const MarkerId('user_exact_location'),
          position: center,
          infoWindow: const InfoWindow(title: 'Your exact location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndex: 4,
        ),
      );

      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final geometry = item['geometry'];
        final location =
            geometry is Map<String, dynamic> ? geometry['location'] : null;
        final lat =
            location is Map<String, dynamic> ? location['lat'] as num? : null;
        final lng =
            location is Map<String, dynamic> ? location['lng'] as num? : null;
        if (lat == null || lng == null) continue;

        final placeId = (item['place_id'] as String?) ?? '${lat}_$lng';
        final name = (item['name'] as String?) ?? 'Nearby Place';
        final vicinity = (item['vicinity'] as String?) ?? '';
        final types = (item['types'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList();
        final isAtm = types.contains('atm');

        nextMarkers.add(
          Marker(
            markerId: MarkerId(placeId),
            position: LatLng(lat.toDouble(), lng.toDouble()),
            infoWindow: InfoWindow(title: name, snippet: vicinity),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isAtm ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueGreen,
            ),
            zIndex: isAtm ? 2 : 3,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _agentMarkersData = nearbyAgents;
        _mapMarkers = nextMarkers;
        _addAgentMarkers(_mapMarkers);
        _mapCircles = {
          Circle(
            circleId: const CircleId('nearby_radius'),
            center: center,
            radius: _nearbyRadiusMeters.toDouble(),
            fillColor: const Color(0x332563EB),
            strokeColor: const Color(0xFF2563EB),
            strokeWidth: 2,
          ),
        };
      });

      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(center, 11),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  Future<void> _syncToCurrentLocationOnOpen() async {
    final center = await _resolveNearbySearchCenter();
    if (!mounted) return;

    setState(() {
      _mapMarkers.removeWhere(
        (marker) => marker.markerId.value == 'user_exact_location',
      );
      _mapMarkers.add(
        Marker(
          markerId: const MarkerId('user_exact_location'),
          position: center,
          infoWindow: const InfoWindow(title: 'Your exact location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndex: 4,
        ),
      );
    });

    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(center, 15),
    );
  }

  Future<List<NearbyMapAgent>> _fetchNearbyAgents(LatLng center) async {
    final uri = Uri.parse('$_apiBaseUrl/agents/nearby').replace(
      queryParameters: {
        'lat': center.latitude.toString(),
        'lng': center.longitude.toString(),
        'radius': widget.nearbyRadiusKm.toString(),
        'includeAll': 'true',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _agentMarkersData;
    }

    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic>
            ? (decoded['agents'] as List<dynamic>? ?? const [])
            : const <dynamic>[]);

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final user = json['user'] is Map<String, dynamic>
              ? json['user'] as Map<String, dynamic>
              : <String, dynamic>{};
          final lat = _toDouble(json['latitude']);
          final lng = _toDouble(json['longitude']);
          if (lat == null || lng == null) return null;
          return NearbyMapAgent(
            id: (json['id'] ?? '').toString(),
            name: (user['name'] ?? json['name'] ?? 'Agent').toString(),
            city: (json['city'] ?? '').toString(),
            shopName: (json['locationName'] ?? '').toString(),
            latitude: lat,
            longitude: lng,
            distanceKm: _toDouble(json['distanceKm']),
          );
        })
        .whereType<NearbyMapAgent>()
        .toList();
  }

  void _addAgentMarkers(Set<Marker> target) {
    for (final agent in _agentMarkersData) {
      target.add(
        Marker(
          markerId: MarkerId('agent_${agent.id}'),
          position: LatLng(agent.latitude, agent.longitude),
          infoWindow: InfoWindow(
            title: agent.name,
            snippet: agent.shopName.isNotEmpty ? agent.shopName : agent.city,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          zIndex: 5,
          onTap: () => _showAgentDetailsSheet(agent),
        ),
      );
    }
  }

  Future<void> _showAgentDetailsSheet(NearbyMapAgent agent) async {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  agent.shopName.isNotEmpty ? agent.shopName : agent.city,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (agent.distanceKm != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Distance: ${agent.distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirectionsForAgent(agent),
                    icon: const Icon(Icons.directions),
                    label: const Text('Open in Google Maps'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDirectionsForAgent(NearbyMapAgent agent) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${agent.latitude},${agent.longitude}',
      'origin': '${_nearbySearchCenter.latitude},${_nearbySearchCenter.longitude}',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps directions')),
      );
    }
  }

  Future<LatLng> _resolveNearbySearchCenter() async {
    try {
      final location = await _locationService.getCurrentLocation();
      final center = LatLng(location.latitude, location.longitude);
      _nearbySearchCenter = center;
      return center;
    } catch (_) {
      // Fall back to the passed center when GPS is unavailable.
      return _nearbySearchCenter;
    }
  }

  String _fmt(double value) => value.toStringAsFixed(5);

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _searchSpecificPlace() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isSearchingPlace = true);
    try {
      final autoUri =
          Uri.parse('$_apiBaseUrl/maps/places-autocomplete').replace(
        queryParameters: {'input': input},
      );

      final autoResp = await http.get(autoUri,
          headers: {'Content-Type': 'application/json'});
      if (autoResp.statusCode < 200 || autoResp.statusCode >= 300) {
        throw Exception('Place search failed');
      }

      final autoBody =
          jsonDecode(autoResp.body) as Map<String, dynamic>;
      if ((autoBody['status'] as String?) == 'REQUEST_DENIED') {
        throw Exception(
            'Google Places request denied. Enable billing and Places API in Google Cloud.');
      }

      final predictions =
          (autoBody['predictions'] as List<dynamic>? ?? []);
      if (predictions.isEmpty) {
        throw Exception('No places found for your search');
      }

      final first = predictions.first as Map<String, dynamic>;
      final placeId = first['place_id'] as String?;
      if (placeId == null || placeId.isEmpty) {
        throw Exception('Invalid place result');
      }

      final detailsUri =
          Uri.parse('$_apiBaseUrl/maps/place-details').replace(
        queryParameters: {'placeId': placeId},
      );

      final detailsResp = await http.get(detailsUri,
          headers: {'Content-Type': 'application/json'});
      if (detailsResp.statusCode < 200 || detailsResp.statusCode >= 300) {
        throw Exception('Failed to get place details');
      }

      final detailsBody =
          jsonDecode(detailsResp.body) as Map<String, dynamic>;
      if ((detailsBody['status'] as String?) == 'REQUEST_DENIED') {
        throw Exception(
            'Google PlaceDetails denied. Check API key and billing.');
      }

      final result = detailsBody['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = location?['lat'] as num?;
      final lng = location?['lng'] as num?;
      if (lat == null || lng == null) {
        throw Exception('No location found for selected place');
      }

      final target = LatLng(lat.toDouble(), lng.toDouble());
      final title = (result?['name'] as String?) ?? input;
      final subtitle = (result?['formatted_address'] as String?) ?? '';

      if (!mounted) return;
      setState(() {
        _mapMarkers
            .removeWhere((m) => m.markerId.value == 'searched_place');
        _mapMarkers.add(
          Marker(
            markerId: const MarkerId('searched_place'),
            position: target,
            infoWindow: InfoWindow(title: title, snippet: subtitle),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          ),
        );
      });

      await _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 15));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSearchingPlace = false);
    }
  }
}

class _MarkerLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _MarkerLegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
