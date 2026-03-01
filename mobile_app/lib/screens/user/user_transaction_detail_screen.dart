import 'package:flutter/material.dart';

class UserTransactionDetailItem {
  final String id;
  final String status;
  final String requestType;
  final int amount;
  final String agentName;
  final String agentPhone;
  final String agentEmail;
  final String shopName;
  final String city;
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const UserTransactionDetailItem({
    required this.id,
    required this.status,
    required this.requestType,
    required this.amount,
    required this.agentName,
    required this.agentPhone,
    required this.agentEmail,
    required this.shopName,
    required this.city,
    required this.address,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });
}

class UserTransactionDetailScreen extends StatelessWidget {
  final dynamic item;

  const UserTransactionDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime? ts = item.completedAt ?? item.updatedAt ?? item.createdAt;
    final tsLabel = ts == null
        ? '-'
        : '${ts.day.toString().padLeft(2, '0')}-${ts.month.toString().padLeft(2, '0')}-${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    final isSuccess = item.status == 'confirmed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: isSuccess ? const Color(0xff16A34A) : Colors.blueGrey,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Text(
              isSuccess ? 'Transaction Successful' : 'Transaction ${item.status.toUpperCase()}',
              style: const TextStyle(
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
                _rowTile('Request Type', item.requestTypeLabel),
                _rowTile('Amount', '₹${item.amount}'),
                _rowTile('Agent Name', item.agentName),
                _rowTile('Mobile Number', item.agentPhone.isEmpty ? '-' : item.agentPhone),
                _rowTile('Time and Date', tsLabel),
                _rowTile('City', item.city.isEmpty ? '-' : item.city),
                _rowTile('Email', item.agentEmail.isEmpty ? '-' : item.agentEmail),
                _rowTile('Shop Name', item.shopName.isEmpty ? '-' : item.shopName),
                _rowTile('Address', item.address.isEmpty ? '-' : item.address),
                _rowTile('Transaction Id', item.id),
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
