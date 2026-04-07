import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/agent_service.dart';
import 'agent_transaction_detail_screen.dart';

class AgentTransactionsScreen extends StatefulWidget {
  const AgentTransactionsScreen({super.key});

  @override
  State<AgentTransactionsScreen> createState() => _AgentTransactionsScreenState();
}

class _AgentTransactionsScreenState extends State<AgentTransactionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<AgentTransactionHistoryItem> _items = const [];
  String _statusFilter = 'all';
  DateTime? _lastSyncedAt;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final items = await AgentService.getTransactionHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = items;
        _lastSyncedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  List<AgentTransactionHistoryItem> _filteredItems() {
    if (_statusFilter == 'all') return _items;
    return _items
        .where((item) => item.status.trim().toLowerCase() == _statusFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('Previous Transactions'),
        actions: [
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _filteredItems().isEmpty
                  ? const Center(child: Text('No previous transactions yet'))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filterChip('All', 'all'),
                                      const SizedBox(width: 8),
                                      _filterChip('Confirmed', 'confirmed'),
                                      const SizedBox(width: 8),
                                      _filterChip('Approved', 'approved'),
                                      const SizedBox(width: 8),
                                      _filterChip('Rejected', 'rejected'),
                                      const SizedBox(width: 8),
                                      _filterChip('Cancelled', 'cancelled'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_lastSyncedAt != null)
                          Container(
                            width: double.infinity,
                            color: const Color(0xffEEF3FF),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Text(
                              'Live synced: ${_formatDateTime(_lastSyncedAt!)}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            itemCount: _filteredItems().length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems()[index];
                              final status = item.status.trim().toLowerCase();
                              final statusColor = status == 'confirmed'
                                  ? const Color(0xff15803D)
                                  : status == 'rejected'
                                      ? const Color(0xffDC2626)
                                      : status == 'cancelled'
                                          ? const Color(0xffD97706)
                                          : const Color(0xff475467);
                              final statusBg = statusColor.withValues(alpha: 0.12);
                              final ts = item.completedAt ?? item.updatedAt ?? item.createdAt;
                              final tsLabel = ts == null ? '-' : _formatDateTime(ts);

                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AgentTransactionDetailScreen(item: item),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xffE6EBF5)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.receipt_long, color: statusColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Received from ${item.userName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _requestTypeLabel(item.requestType),
                                              style: const TextStyle(color: Colors.black87, fontSize: 12),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              tsLabel,
                                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${item.agentReceived}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xff111827),
                                            ),
                                          ),
                                          Text(
                                            'Earnings ₹${item.agentCommission}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xff475569),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.status.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? const Color(0xff244BB3) : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xffE6EEFF),
      backgroundColor: const Color(0xffF6F8FC),
      side: BorderSide(
        color: selected ? const Color(0xffAEC3FF) : const Color(0xffDFE5F3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }

  String _requestTypeLabel(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'cash_to_upi' || normalized == 'cash to upi') {
      return 'Cash to UPI';
    }
    if (normalized == 'upi_to_cash' || normalized == 'upi to cash') {
      return 'UPI to Cash';
    }
    return rawType;
  }

  String _formatDateTime(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final yyyy = dateTime.year.toString();
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    final sec = dateTime.second.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min:$sec';
  }
}
