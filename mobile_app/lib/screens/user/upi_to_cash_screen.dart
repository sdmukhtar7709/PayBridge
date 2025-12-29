import 'package:flutter/material.dart';

class UpiToCashScreen extends StatefulWidget {
  const UpiToCashScreen({super.key});

  @override
  State<UpiToCashScreen> createState() => _UpiToCashScreenState();
}

class _UpiToCashScreenState extends State<UpiToCashScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String _distance = '1-2 km';
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
        title: const Text('UPI to Cash'),
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
              _distanceSelector(),
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
                  // TODO: Call backend API to fetch nearby agents based on distance, city, and location
                  // TODO: Show agent list and map view after backend response
                  // TODO: Enable routing after agent approval
                  debugPrint('Check availability tapped');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Check Availability'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: This will filter all registered Cash IO trusted agents based on your preferences.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distanceSelector() {
    const options = ['1-2 km', '2-5 km', '5-10 km'];
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance Range',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _distance,
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
              // TODO: Hook into location services to fetch GPS when enabled
            },
          ),
        ],
      ),
    );
  }
}
