import 'package:flutter/material.dart';

import '../../services/agent_service.dart';

class AgentTransactionDetailScreen extends StatelessWidget {
  final AgentTransactionHistoryItem item;

  const AgentTransactionDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final ts = item.completedAt ?? item.createdAt;
    final tsLabel = ts == null
        ? '-'
        : '${ts.day.toString().padLeft(2, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xff16A34A),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: const Text(
              'Transaction Successful',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _rowTile('Status', item.status.toUpperCase()),
                _rowTile('Request Type', item.requestType),
                _rowTile('Amount', '₹${item.amount}'),
                _rowTile('Mobile Number', item.userPhone.isEmpty ? '-' : item.userPhone),
                _rowTile('Time and Date', tsLabel),
                _rowTile('City', item.userCity.isEmpty ? '-' : item.userCity),
                _rowTile('Email', item.userEmail.isEmpty ? '-' : item.userEmail),
                _rowTile('User Id', item.userId.isEmpty ? '-' : item.userId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
