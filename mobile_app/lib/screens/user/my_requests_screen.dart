import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/request_type_store.dart';
import 'user_transaction_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  static const String _apiBaseUrl = ApiConfig.baseUrl;

  bool _isLoading = true;
  String? _error;
  List<_UserRequestItem> _items = const [];
  String _statusFilter = 'confirmed';
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
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please login first');
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/transactions/requests?limit=100'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readError(body, 'Failed to load requests'));
      }

      final data = body['items'];
      var list = data is List
          ? data.whereType<Map<String, dynamic>>().map(_UserRequestItem.fromJson).toList()
          : <_UserRequestItem>[];

      final savedTypeMap = await RequestTypeStore.getTypeMap();
      list = list
          .map((item) {
            if (item.requestType.isNotEmpty) return item;
            final savedType = savedTypeMap[item.id] ?? '';
            if (savedType.isEmpty) return item;
            return item.copyWith(requestType: savedType);
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _items = list;
        _lastSyncedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<_UserRequestItem> _filteredItems() {
    if (_statusFilter == 'all') return _items;
    return _items.where((item) => item.status == _statusFilter).toList();
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }

  String _readError(Map<String, dynamic> body, String fallback) {
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : filtered.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('Completed', 'confirmed'),
                                const SizedBox(width: 8),
                                _filterChip('All', 'all'),
                                const SizedBox(width: 8),
                                _filterChip('Pending', 'pending'),
                                const SizedBox(width: 8),
                                _filterChip('Approved', 'approved'),
                                const SizedBox(width: 8),
                                _filterChip('Rejected', 'rejected'),
                              ],
                            ),
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
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final statusColor = _statusColor(item.status);
                              final ts = item.completedAt ?? item.updatedAt ?? item.createdAt;
                              final tsLabel = ts == null ? '-' : _formatDateTime(ts);

                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UserTransactionDetailScreen(item: item),
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
                                        child: Icon(Icons.north_east, color: statusColor, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Transaction with ${item.agentName}',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.requestTypeLabel,
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

  Color _statusColor(String status) {
    Color color;
    if (status == 'pending') {
      color = Colors.orange;
    } else if (status == 'approved') {
      color = Colors.blue;
    } else if (status == 'rejected') {
      color = Colors.red;
    } else if (status == 'confirmed') {
      color = Colors.green;
    } else {
      color = Colors.blueGrey;
    }

    return color;
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

class _UserRequestItem {
  final String id;
  final String status;
  final String requestType;
  final int amount;
  final String agentName;
  final String agentPhone;
  final String agentEmail;
  final String shopName;
  final String address;
  final String city;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const _UserRequestItem({
    required this.id,
    required this.status,
    required this.requestType,
    required this.amount,
    required this.agentName,
    required this.agentPhone,
    required this.agentEmail,
    required this.shopName,
    required this.address,
    required this.city,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
  });

  String get requestTypeLabel {
    if (requestType.trim().isEmpty) return 'Unknown';
    return requestType;
  }

  _UserRequestItem copyWith({
    String? requestType,
  }) {
    return _UserRequestItem(
      id: id,
      status: status,
      requestType: requestType ?? this.requestType,
      amount: amount,
      agentName: agentName,
      agentPhone: agentPhone,
      agentEmail: agentEmail,
      shopName: shopName,
      address: address,
      city: city,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
    );
  }

  String get createdAtLabel {
    if (createdAt == null) return '-';
    final value = createdAt!;
    return '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  factory _UserRequestItem.fromJson(Map<String, dynamic> json) {
    final agent = json['agent'] is Map<String, dynamic>
        ? json['agent'] as Map<String, dynamic>
        : <String, dynamic>{};
    final agentUser = agent['user'] is Map<String, dynamic>
        ? agent['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    DateTime? createdAt;
    final createdRaw = json['createdAt']?.toString();
    if (createdRaw != null && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    DateTime? updatedAt;
    final updatedRaw = json['updatedAt']?.toString();
    if (updatedRaw != null && updatedRaw.isNotEmpty) {
      updatedAt = DateTime.tryParse(updatedRaw);
    }

    DateTime? completedAt;
    final completedRaw = json['completedAt']?.toString();
    if (completedRaw != null && completedRaw.isNotEmpty) {
      completedAt = DateTime.tryParse(completedRaw);
    }

    return _UserRequestItem(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString().toLowerCase(),
      requestType: (json['requestType'] ?? '').toString(),
      amount: int.tryParse((json['amount'] ?? '0').toString()) ?? 0,
      agentName: (agentUser['name'] ?? 'Agent').toString(),
      agentPhone: (agentUser['phone'] ?? '').toString(),
      agentEmail: (agentUser['email'] ?? '').toString(),
      shopName: (agent['locationName'] ?? '').toString(),
      address: (agentUser['address'] ?? '').toString(),
      city: (agent['city'] ?? 'Unknown city').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
    );
  }
}
