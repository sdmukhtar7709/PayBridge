import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/agent_rating_live_store.dart';
import '../../../services/user_service.dart';
import '../../shared/transactions/transaction_receipt_view.dart';

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

class UserTransactionDetailScreen extends StatefulWidget {
  final dynamic item;

  const UserTransactionDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<UserTransactionDetailScreen> createState() => _UserTransactionDetailScreenState();
}

class _UserTransactionDetailScreenState extends State<UserTransactionDetailScreen> {
  User? _userProfile;
  StreamSubscription<AgentRatingLiveUpdate>? _ratingLiveSub;
  double? _liveAgentAverage;
  int _liveAgentRatingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    final agentId = _safe('${widget.item.agentId ?? ''}');
    if (agentId != '-') {
      _ratingLiveSub = AgentRatingLiveStore.instance.stream.listen((update) {
        if (!mounted || update.agentId != agentId) return;
        setState(() {
          _liveAgentAverage = update.averageRating;
          _liveAgentRatingCount = update.ratingCount;
        });
      });
    }
  }

  @override
  void dispose() {
    _ratingLiveSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService().getCachedProfile();
      if (!mounted) return;
      setState(() => _userProfile = profile);
    } catch (_) {
      // Receipt UI gracefully falls back to placeholders when profile cache is not available.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final DateTime? ts = item.completedAt ?? item.updatedAt ?? item.createdAt;

    final userName = (_userProfile?.displayName ?? '').trim().isEmpty
        ? 'You'
        : _userProfile!.displayName.trim();
    final userPhone = (_userProfile?.phone ?? '').trim();

    final otpVerified = item.approvedAt != null || item.status == 'confirmed';
    final confirmedByAgent = item.agentConfirmedAt != null || item.status == 'confirmed';
    final confirmedByUser = item.userConfirmedAt != null || item.status == 'confirmed';

    return TransactionReceiptView(
      status: item.status,
      amount: item.amount,
      dateTimeLabel: _formatDateTime(ts),
      emphasizeAgentDetails: true,
      agentDetails: ReceiptPersonData(
        name: _safe(item.agentName),
        ratingLabel: _agentRatingLabel(item),
        phone: _safe(item.agentPhone),
        shopName: _safe(item.shopName),
        city: _safe(item.city),
        address: _safe(item.address),
      ),
      userDetails: ReceiptPersonData(
        name: userName,
        phone: userPhone.isEmpty ? '-' : userPhone,
      ),
      transactionId: _safe(item.id),
      requestType: _safe(item.requestTypeLabel),
      city: _safe(item.city),
      fullAddress: _safe(item.address),
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

  String _agentRatingLabel(dynamic item) {
    if (_liveAgentAverage != null && _liveAgentRatingCount > 0) {
      return '${_liveAgentAverage!.toStringAsFixed(1)} / 5 ($_liveAgentRatingCount ratings)';
    }
    final avgRaw = item.agentAverageRating;
    final countRaw = item.agentRatingCount;
    final count = countRaw is int ? countRaw : int.tryParse('$countRaw') ?? 0;
    if (avgRaw == null || count <= 0) return 'New';
    final avg = avgRaw is num ? avgRaw.toDouble() : double.tryParse('$avgRaw');
    if (avg == null) return 'New';
    return '${avg.toStringAsFixed(1)} / 5 ($count ratings)';
  }
}
