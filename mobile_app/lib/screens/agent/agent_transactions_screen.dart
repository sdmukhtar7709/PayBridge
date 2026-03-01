import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/agent_service.dart';
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
    return _items.where((item) => item.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Transactions'),
        actions: [
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : _filteredItems().isEmpty
                  ? const Center(child: Text('No transactions yet'))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                            color: const Color(0xffF8FAFF),
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Text(
                              'Live synced: ${_formatDateTime(_lastSyncedAt!)}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      itemCount: _filteredItems().length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems()[index];
                        final statusColor = item.status == 'confirmed'
                            ? Colors.green
                            : item.status == 'rejected'
                                ? Colors.red
                                : item.status == 'cancelled'
                                    ? Colors.orange
                                    : Colors.blueGrey;
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
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.south_west, color: statusColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Received from ${item.userName}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.requestType,
                                        style: const TextStyle(color: Colors.black87, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tsLabel,
                                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.amount}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
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
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
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
