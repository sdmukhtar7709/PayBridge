import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';

class AgentDirectionsScreen extends StatefulWidget {
  final String agentName;
  final LatLng origin;
  final LatLng destination;

  const AgentDirectionsScreen({
    super.key,
    required this.agentName,
    required this.origin,
    required this.destination,
  });

  @override
  State<AgentDirectionsScreen> createState() => _AgentDirectionsScreenState();
}

class _AgentDirectionsScreenState extends State<AgentDirectionsScreen> {
  static final String _apiBaseUrl = ApiConfig.baseUrl;

  GoogleMapController? _mapController;
  bool _isLoading = true;
  String? _error;
  String _distanceText = '-';
  String _durationText = '-';
  String _startAddress = '';
  String _endAddress = '';
  final Set<Polyline> _polylines = <Polyline>{};
  bool _hasTriggeredExternalFallback = false;

  @override
  void initState() {
    super.initState();
    _loadDirections();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadDirections() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiBaseUrl/maps/directions').replace(
        queryParameters: {
          'originLat': widget.origin.latitude.toString(),
          'originLng': widget.origin.longitude.toString(),
          'destLat': widget.destination.latitude.toString(),
          'destLng': widget.destination.longitude.toString(),
          'mode': 'driving',
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to load route (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map<String, dynamic>) {
            final errorText = (err['error'] ?? '').toString().trim();
            final statusText = (err['status'] ?? '').toString().trim();
            if (errorText.isNotEmpty && statusText.isNotEmpty) {
              message = '$errorText ($statusText)';
            } else if (errorText.isNotEmpty) {
              message = errorText;
            } else if (statusText.isNotEmpty) {
              message = statusText;
            }
          }
        } catch (_) {}
        throw Exception(message);
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Invalid directions response');
      }

      final polylinePoints = (body['routePolyline'] ?? '').toString();
      final routeCoordinates = _decodePolyline(polylinePoints);

      if (!mounted) return;
      setState(() {
        _distanceText = (body['distanceText'] ?? '-').toString();
        _durationText = (body['durationText'] ?? '-').toString();
        _startAddress = (body['startAddress'] ?? '').toString();
        _endAddress = (body['endAddress'] ?? '').toString();
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('agent_route'),
              color: const Color(0xFF2563EB),
              width: 6,
              points: routeCoordinates,
            ),
          );
      });

      await _fitRouteInView(routeCoordinates);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      if (!_hasTriggeredExternalFallback) {
        _hasTriggeredExternalFallback = true;
        await _openExternalDirections();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openExternalDirections() async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${widget.origin.latitude},${widget.origin.longitude}',
      'destination': '${widget.destination.latitude},${widget.destination.longitude}',
      'travelmode': 'driving',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open fallback Google Maps directions')),
      );
    }
  }

  Future<void> _fitRouteInView(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) {
      return [widget.origin, widget.destination];
    }

    final List<LatLng> poly = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route to ${widget.agentName}'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.origin, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: {
              Marker(
                markerId: const MarkerId('origin'),
                position: widget.origin,
                infoWindow: const InfoWindow(title: 'You'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                infoWindow: InfoWindow(title: widget.agentName),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
              ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
              if (_polylines.isNotEmpty) {
                _fitRouteInView(_polylines.first.points);
              }
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
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
              child: _isLoading
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Loading route...'),
                      ],
                    )
                  : _error != null
                      ? Text(_error!, style: const TextStyle(color: Colors.redAccent))
                      : Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.directions_car, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_distanceText • $_durationText',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _startAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  Text(
                                    _endAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
