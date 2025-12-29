import 'package:flutter/material.dart';

class UpiCard extends StatelessWidget {
  final String upiId;
  final VoidCallback onCopy;

  const UpiCard({
    super.key,
    required this.upiId,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffe8f3ff),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UPI ID',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  upiId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
