import 'package:flutter/material.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final String amount;
  final String agentName;
  final String agentPhone;
  final String city;
  final String shopName;

  const TransactionSuccessScreen({
    super.key,
    required this.amount,
    required this.agentName,
    required this.agentPhone,
    required this.city,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6FBF8),
      appBar: AppBar(
        title: const Text('Transaction Successful'),
        backgroundColor: const Color(0xffF6FBF8),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.check_circle, size: 84, color: Color(0xff16A34A)),
            const SizedBox(height: 14),
            const Text(
              'Transaction Successful',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xff065F46)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for transaction with us!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ₹$amount', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Agent: $agentName'),
                  if (agentPhone.isNotEmpty) Text('Mobile: $agentPhone'),
                  if (shopName.isNotEmpty) Text('Shop: $shopName'),
                  if (city.isNotEmpty) Text('City: $city'),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff16A34A),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
