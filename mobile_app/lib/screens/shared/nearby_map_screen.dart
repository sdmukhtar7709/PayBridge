import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Full-screen map with satellite toggle, nearby ATMs/banks, and place search.
/// Shared between UserHomeScreen and AgentHomeScreen.
class NearbyMapScreen extends StatefulWidget {
  final LatLng initialCenter;
  final Set<Marker> markers;

  const NearbyMapScreen({
    super.key,
    required this.initialCenter,
    required this.markers,
  });

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  static const String _apiBaseUrl = ApiConfig.baseUrl;

  GoogleMapController? _controller;
  final TextEditingController _searchController = TextEditingController();
  bool _isSatelliteSelected = false;
  bool _isLoadingNearby = false;
  bool _isSearchingPlace = false;
  late Set<Marker> _mapMarkers;

  @override
  void initState() {
    super.initState();
    _mapMarkers = Set<Marker>.from(widget.markers);
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
      appBar: AppBar(
        title: const Text('Nearby Banks & ATMs'),
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
            onMapCreated: (controller) {
              _controller = controller;
            },
          ),
          // Nearby ATMs & Banks button
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
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // Search bar
          Positioned(
            top: 68,
            left: 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
      final uri = Uri.parse(
        '$_apiBaseUrl/maps/nearby-banks-atms?lat=${widget.initialCenter.latitude}&lng=${widget.initialCenter.longitude}&radius=3000',
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

      final nextMarkers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: widget.initialCenter,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
        ),
      };

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
              isAtm
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueRed,
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _mapMarkers = nextMarkers);
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
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
