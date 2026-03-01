import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/user_service.dart';
import 'available_agents_screen.dart';
import 'my_requests_screen.dart';

class CashToUpiScreen extends StatefulWidget {
  const CashToUpiScreen({super.key});

  @override
  State<CashToUpiScreen> createState() => _CashToUpiScreenState();
}

class _CashToUpiScreenState extends State<CashToUpiScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();
  bool _useCurrentLocation = true;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;
  _LastAvailabilityArgs? _lastAvailability;

  @override
  void dispose() {
    _amountController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _useDeviceLocation();
  }

  Future<void> _useDeviceLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      try {
        await _userService.updateProfile({'address': location.address});
      } catch (_) {
        // Ignore profile persistence errors to keep location UI responsive.
      }
      if (!mounted) return;
      setState(() {
        _useCurrentLocation = true;
        _cityController.text = location.city;
        _latitude = location.latitude;
        _longitude = location.longitude;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _useCurrentLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash to UPI'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              _locationToggle(),
              if (_isFetchingLocation) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                enabled: !_useCurrentLocation,
                decoration: InputDecoration(
                  labelText: 'City (if not using location)',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final city = _cityController.text.trim();
                  final amount = _amountController.text.trim();
                  if (amount.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an amount')),
                    );
                    return;
                  }
                  final latitude = _useCurrentLocation ? _latitude : null;
                  final longitude = _useCurrentLocation ? _longitude : null;
                  final args = _LastAvailabilityArgs(
                    city: city.isEmpty ? 'your area' : city,
                    latitude: latitude,
                    longitude: longitude,
                    radiusKm: 5.0,
                    transactionType: 'Cash → UPI',
                    amount: amount,
                  );
                  setState(() => _lastAvailability = args);
                  _openAvailableAgents(args);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Check Agent Availability'),
              ),
              if (_lastAvailability != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openAvailableAgents(_lastAvailability!),
                  icon: const Icon(Icons.restore),
                  label: const Text('Regain Available Agents Screen'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('View My Raised Requests'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '* Nearby availability will be filtered based on your location and registered trusted Cash IO agents.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAvailableAgents(_LastAvailabilityArgs args) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvailableAgentsScreen(
          city: args.city,
          latitude: args.latitude,
          longitude: args.longitude,
          radiusKm: args.radiusKm,
          transactionType: args.transactionType,
          amount: args.amount,
        ),
      ),
    );
  }

  Widget _locationToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Use Current Location',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: _useCurrentLocation,
            onChanged: (val) async {
              if (val) {
                await _useDeviceLocation();
                return;
              }
              setState(() {
                _useCurrentLocation = false;
                _latitude = null;
                _longitude = null;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _LastAvailabilityArgs {
  final String city;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final String transactionType;
  final String amount;

  const _LastAvailabilityArgs({
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.transactionType,
    required this.amount,
  });
}
