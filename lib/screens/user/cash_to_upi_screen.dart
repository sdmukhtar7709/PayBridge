import 'package:flutter/material.dart';

class CashToUpiScreen extends StatefulWidget {
  const CashToUpiScreen({super.key});

  @override
  State<CashToUpiScreen> createState() => _CashToUpiScreenState();
}

class _CashToUpiScreenState extends State<CashToUpiScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _useCurrentLocation = true;

  @override
  void dispose() {
    _amountController.dispose();
    _cityController.dispose();
    super.dispose();
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
                  // TODO: Call backend API to filter and return nearby agents based on amount, location, and city
                  debugPrint('Check Agent Availability tapped');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Check Agent Availability'),
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

  Widget _locationToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            onChanged: (val) {
              setState(() => _useCurrentLocation = val);
              // UI-only toggle; no GPS logic
            },
          ),
        ],
      ),
    );
  }
}
