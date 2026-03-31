import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/user_service.dart';
import 'available_agents/available_agents_screen.dart';
import 'transactions/my_requests_screen.dart';

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
              _headerSection(
                title: 'Deposit Cash',
                subtitle: 'Convert your cash into digital balance',
              ),
              const SizedBox(height: 18),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: '₹ 0',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2B59FF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Min ₹100 • Max ₹10,000',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _quickAmountButton('500'),
                        _quickAmountButton('1000'),
                        _quickAmountButton('2000'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isFetchingLocation ? null : _useDeviceLocation,
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _isFetchingLocation
                              ? 'Fetching Current Location...'
                              : 'Use Current Location',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      onChanged: (value) {
                        final hasManualCity = value.trim().isNotEmpty;
                        if (hasManualCity && _useCurrentLocation) {
                          setState(() {
                            _useCurrentLocation = false;
                            _latitude = null;
                            _longitude = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Enter City',
                        hintText: 'Enter City',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isFetchingLocation) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
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
                  _openAvailableAgents(args);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B59FF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Find Nearby Agents'),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Why this is safe',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    SizedBox(height: 10),
                    _TrustBullet(text: 'Verified Agents Only'),
                    SizedBox(height: 8),
                    _TrustBullet(text: 'Secure OTP-Based Exchange'),
                    SizedBox(height: 8),
                    _TrustBullet(text: 'Safe & Transparent Transactions'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('View My Requests'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAmountButton(String amount) {
    return ActionChip(
      label: Text('₹$amount'),
      onPressed: () {
        _amountController.text = amount;
      },
      backgroundColor: const Color(0xFFF2F5FF),
      side: const BorderSide(color: Color(0xFFD4DEFF)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _headerSection({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF2F5FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TrustBullet extends StatelessWidget {
  final String text;

  const _TrustBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            '✔',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B59FF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, height: 1.3),
          ),
        ),
      ],
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
