import 'package:flutter/material.dart';

import '../../../services/agent_service.dart';
import '../../shared/transactions/transaction_receipt_view.dart';

class AgentTransactionDetailScreen extends StatefulWidget {
  final AgentTransactionHistoryItem item;

  const AgentTransactionDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<AgentTransactionDetailScreen> createState() => _AgentTransactionDetailScreenState();
}

class _AgentTransactionDetailScreenState extends State<AgentTransactionDetailScreen> {
  AgentProfileData? _agentProfile;

  @override
  void initState() {
    super.initState();
    _loadAgentProfile();
  }

  Future<void> _loadAgentProfile() async {
    try {
      final profile = await AgentService.getCachedProfile();
      if (!mounted) return;
      setState(() => _agentProfile = profile);
    } catch (_) {
      // Receipt UI falls back to placeholders when cache is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ts = item.completedAt ?? item.updatedAt ?? item.createdAt;
    final otpVerified = item.approvedAt != null || item.status == 'confirmed';
    final confirmedByAgent = item.agentConfirmedAt != null || item.status == 'confirmed';
    final confirmedByUser = item.userConfirmedAt != null || item.status == 'confirmed';
    final locationCity = _safe(_agentProfile?.city ?? '').trim() == '-'
      ? _safe(item.userCity)
      : _safe(_agentProfile?.city ?? '');
    final locationAddress = _safe(_agentProfile?.address ?? '').trim() == '-'
      ? _safe(item.userAddress)
      : _safe(_agentProfile?.address ?? '');

    return TransactionReceiptView(
      status: item.status,
      amount: item.amount,
      agentCommission: item.agentCommission,
      totalPaid: item.totalPaid,
      agentReceived: item.agentReceived,
      dateTimeLabel: _formatDateTime(ts),
      emphasizeAgentDetails: false,
      agentDetails: ReceiptPersonData(
        name: _safe((_agentProfile?.name ?? '').trim().isEmpty ? 'You' : _agentProfile!.name),
        phone: _safe(_agentProfile?.phone ?? ''),
        shopName: _safe(_agentProfile?.locationName ?? ''),
        city: _safe(_agentProfile?.city ?? ''),
        address: _safe(_agentProfile?.address ?? ''),
      ),
      userDetails: ReceiptPersonData(
        name: _safe(item.userName),
        phone: _safe(item.userPhone),
      ),
      transactionId: _safe(item.id),
      requestType: _safe(item.requestType),
      city: locationCity,
      fullAddress: locationAddress,
      otpVerified: otpVerified,
      confirmedByAgent: confirmedByAgent,
      confirmedByUser: confirmedByUser,
    );
  }

  String _safe(String value) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final yyyy = dateTime.year.toString();
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min';
  }
}
