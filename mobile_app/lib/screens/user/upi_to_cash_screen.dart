import 'package:flutter/material.dart';

import '../../services/agent_fee_calculator.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../widgets/responsive_utils.dart';
import 'available_agents/available_agents_screen.dart';
import 'transactions/my_requests_screen.dart';

class UpiToCashScreen extends StatefulWidget {
  const UpiToCashScreen({super.key});

  @override
  State<UpiToCashScreen> createState() => _UpiToCashScreenState();
}

class _UpiToCashScreenState extends State<UpiToCashScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  String _distance = '1-2 km';
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
        await _userService.updateProfile({
          'address': location.address,
          'city': location.city,
        });
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
        title: const Text('UPI to Cash'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pagePadding = Responsive.pagePadding(context);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                pagePadding.left,
                16,
                pagePadding.right,
                20 +
                    MediaQuery.of(context).padding.bottom +
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth >= 900 ? 760 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              _headerSection(
                title: 'Withdraw Cash',
                subtitle: 'Convert your digital balance into cash safely',
              ),
              const SizedBox(height: 18),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
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
                    if (_amountBreakdown.amount > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffDCE6FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _amountRow('Amount', _amountBreakdown.amount),
                            const SizedBox(height: 8),
                            _amountRow('Agent Fee', _amountBreakdown.agentFee),
                            const Divider(height: 18),
                            _amountRow(
                              'Total Payable',
                              _amountBreakdown.totalPayable,
                              emphasize: true,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Agent fee applied for service',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xff64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    const SizedBox(height: 10),
                    _distanceSelector(),
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
                  final radius = 10.0;
                  final latitude = _useCurrentLocation ? _latitude : null;
                  final longitude = _useCurrentLocation ? _longitude : null;
                  final args = _LastAvailabilityArgs(
                    city: city.isEmpty ? 'your area' : city,
                    latitude: latitude,
                    longitude: longitude,
                    radiusKm: radius,
                    transactionType: 'UPI → Cash',
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
          },
          ),
      ),
    );
  }

  Widget _quickAmountButton(String amount) {
    return ActionChip(
      label: Text('₹$amount'),
      onPressed: () {
        _amountController.text = amount;
        setState(() {});
      },
      backgroundColor: const Color(0xFFF2F5FF),
      side: const BorderSide(color: Color(0xFFD4DEFF)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  AgentFeeBreakdown get _amountBreakdown {
    return AgentFeeCalculator.fromRawAmount(_amountController.text);
  }

  Widget _amountRow(String label, int value, {bool emphasize = false}) {
    final scaleFactor = Responsive.scaleFactor(context);
    final style = TextStyle(
      fontSize: (emphasize ? 17 : 14) * scaleFactor,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: emphasize ? const Color(0xff0F172A) : const Color(0xff334155),
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '₹$value',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
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

  Widget _distanceSelector() {
    const options = ['1-2 km', '2-5 km', '5-10 km'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distance Filter',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _distance,
          items: options
              .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _distance = val);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _headerSection({required String title, required String subtitle}) {
    final scaleFactor = Responsive.scaleFactor(context);
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
            style: TextStyle(fontSize: 24 * scaleFactor, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
