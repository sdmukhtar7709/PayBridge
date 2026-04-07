import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/agent_rating_live_store.dart';
import '../../../services/local_notification_service.dart';
import '../../../services/request_type_store.dart';
import 'user_transaction_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  final String? initialRequestId;

  const MyRequestsScreen({super.key, this.initialRequestId});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  static final String _apiBaseUrl = ApiConfig.baseUrl;

  bool _isLoading = true;
  String? _error;
  List<_UserRequestItem> _items = const [];
  String _statusFilter = 'all';
  DateTime? _lastSyncedAt;
  Timer? _refreshTimer;
  String? _archivingId;
  bool _openedInitialRequest = false;
  final Map<String, String> _lastNotifiedStatusById = {};

  Future<void> _submitRating(_UserRequestItem item, int rating) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/transactions/requests/${item.id}/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'rating': rating}),
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readError(body, 'Failed to submit rating'));
      }

      final ratedAt = DateTime.tryParse((body['ratedAt'] ?? '').toString());
      final avgRaw = body['agentRatingAverage'];
      final countRaw = body['agentRatingCount'];
      final avgRating = avgRaw is num ? avgRaw.toDouble() : double.tryParse('$avgRaw');
      final ratingCount = countRaw is int ? countRaw : int.tryParse('$countRaw') ?? item.agentRatingCount;
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((entry) => entry.id == item.id
                ? entry.copyWith(
                    userRating: rating,
                    ratedAt: ratedAt ?? DateTime.now(),
                    agentAverageRating: avgRating ?? entry.agentAverageRating,
                    agentRatingCount: ratingCount,
                  )
                : entry)
            .toList();
      });

      if (item.agentId.isNotEmpty && avgRating != null && ratingCount > 0) {
        AgentRatingLiveStore.instance.emit(
          AgentRatingLiveUpdate(
            agentId: item.agentId,
            averageRating: avgRating,
            ratingCount: ratingCount,
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! You rated ${item.agentName} $rating/5')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openRatingDialog(_UserRequestItem item) async {
    int selected = 5;
    final choice = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Rate Agent'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setLocalState(() => selected = value),
                    icon: Icon(
                      value <= selected ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (choice == null) return;
    await _submitRating(item, choice);
  }

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

      _notifyStatusChanges(list);

      if (!_openedInitialRequest && widget.initialRequestId != null) {
        final target = list.firstWhere(
          (item) => item.id == widget.initialRequestId,
          orElse: () => list.isNotEmpty ? list.first : _UserRequestItem.empty(),
        );
        if (target.id.isNotEmpty && mounted) {
          _openedInitialRequest = true;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserTransactionDetailScreen(
                item: target,
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _notifyStatusChanges(List<_UserRequestItem> items) {
    for (final item in items) {
      final previous = _lastNotifiedStatusById[item.id];
      _lastNotifiedStatusById[item.id] = item.status;
      if (previous == null || previous == item.status) continue;

      final title = _statusTitle(item.status);
      final message = _statusMessage(item);
      if (title.isEmpty || message.isEmpty) continue;

      LocalNotificationService.instance.showUserStatusNotification(
        title: title,
        message: message,
        payload: _notificationPayload(item),
      );
    }
  }

  String _notificationPayload(_UserRequestItem item) {
    if (item.status == 'approved') {
      return 'user_approved:${item.id}';
    }
    return 'user_request:${item.id}';
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Request Pending';
      case 'approved':
        return 'Request Approved';
      case 'rejected':
        return 'Request Rejected';
      case 'cancelled':
        return 'Request Cancelled';
      case 'confirmed':
        return 'Transaction Completed';
      default:
        return '';
    }
  }

  String _statusMessage(_UserRequestItem item) {
    switch (item.status) {
      case 'pending':
        return 'Your request is pending with ${item.agentName}.';
      case 'approved':
        return 'Agent approved your request. OTP is ready.';
      case 'rejected':
        return 'Agent rejected your request. Try another agent.';
      case 'cancelled':
        return 'Your request has been cancelled.';
      case 'confirmed':
        return 'Your transaction is completed successfully.';
      default:
        return '';
    }
  }

  // ignore: unused_element
  Future<void> _archiveRequest(_UserRequestItem item) async {
    if (_archivingId != null) return;
    setState(() => _archivingId = item.id);

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please login first');
      }

      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/transactions/requests/${item.id}/archive'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          if (!mounted) return;
          setState(() {
            _items = _items.where((entry) => entry.id != item.id).toList();
          });
          await RequestTypeStore.removeType(item.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cleared from your list')),
          );
          return;
        }
        throw Exception(_readError(body, 'Failed to clear request'));
      }

      if (!mounted) return;
      setState(() {
        _items = _items.where((entry) => entry.id != item.id).toList();
      });
      await RequestTypeStore.removeType(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cleared from your list')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _archivingId = null);
    }
  }

  List<_UserRequestItem> _filteredItems() {
    if (_statusFilter == 'all') return _items;
    return _items
        .where((item) => item.status.trim().toLowerCase() == _statusFilter)
        .toList();
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
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('Previous Transactions'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : filtered.isEmpty
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
                                      _filterChip('Completed', 'confirmed'),
                                      const SizedBox(width: 8),
                                      _filterChip('Pending', 'pending'),
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
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final statusColor = _statusColor(item.status);
                              final statusBg = statusColor.withValues(alpha: 0.12);
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
                                              'Transaction with ${item.agentName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _requestTypeLabel(item.requestTypeLabel),
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
                                            '₹${item.totalPaid}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xff111827),
                                            ),
                                          ),
                                          Text(
                                            'Agent Fee ₹${item.agentCommission}',
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
                                          if (item.status == 'confirmed' && item.userRating == null)
                                            TextButton(
                                              onPressed: () => _openRatingDialog(item),
                                              style: TextButton.styleFrom(
                                                minimumSize: const Size(0, 0),
                                                padding: const EdgeInsets.only(top: 4),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                foregroundColor: const Color(0xff2563EB),
                                              ),
                                              child: const Text(
                                                'Rate Agent',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          if (item.userRating != null)
                                            Text(
                                              'Rated ${item.userRating}/5',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.black54,
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

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'pending') return const Color(0xffD97706);
    if (normalized == 'approved') return const Color(0xff2563EB);
    if (normalized == 'rejected') return const Color(0xffDC2626);
    if (normalized == 'confirmed') return const Color(0xff15803D);
    if (normalized == 'cancelled') return const Color(0xff6B7280);
    return const Color(0xff475467);
  }

  String _requestTypeLabel(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized == 'cash_to_upi' || normalized == 'cash to upi') {
      return 'Cash to UPI';
    }
    if (normalized == 'upi_to_cash' || normalized == 'upi to cash') {
      return 'UPI to Cash';
    }
    return rawType.trim().isEmpty ? 'Unknown' : rawType;
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
  final String agentId;
  final String status;
  final String requestType;
  final int amount;
  final int agentCommission;
  final int totalPaid;
  final int agentReceived;
  final String agentName;
  final String agentPhone;
  final String agentEmail;
  final String shopName;
  final String address;
  final String city;
  final double? agentAverageRating;
  final int agentRatingCount;
  final DateTime? approvedAt;
  final DateTime? userConfirmedAt;
  final DateTime? agentConfirmedAt;
  final int? userRating;
  final DateTime? ratedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const _UserRequestItem({
    required this.id,
    required this.agentId,
    required this.status,
    required this.requestType,
    required this.amount,
    required this.agentCommission,
    required this.totalPaid,
    required this.agentReceived,
    required this.agentName,
    required this.agentPhone,
    required this.agentEmail,
    required this.shopName,
    required this.address,
    required this.city,
    required this.agentAverageRating,
    required this.agentRatingCount,
    required this.approvedAt,
    required this.userConfirmedAt,
    required this.agentConfirmedAt,
    required this.userRating,
    required this.ratedAt,
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
    int? userRating,
    DateTime? ratedAt,
    double? agentAverageRating,
    int? agentRatingCount,
    String? agentId,
  }) {
    return _UserRequestItem(
      id: id,
      agentId: agentId ?? this.agentId,
      status: status,
      requestType: requestType ?? this.requestType,
      amount: amount,
      agentCommission: agentCommission,
      totalPaid: totalPaid,
      agentReceived: agentReceived,
      agentName: agentName,
      agentPhone: agentPhone,
      agentEmail: agentEmail,
      shopName: shopName,
      address: address,
      city: city,
      agentAverageRating: agentAverageRating ?? this.agentAverageRating,
      agentRatingCount: agentRatingCount ?? this.agentRatingCount,
      approvedAt: approvedAt,
      userConfirmedAt: userConfirmedAt,
      agentConfirmedAt: agentConfirmedAt,
      userRating: userRating ?? this.userRating,
      ratedAt: ratedAt ?? this.ratedAt,
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
    final ratingSum = int.tryParse((agent['ratingSum'] ?? '0').toString()) ?? 0;
    final ratingCount = int.tryParse((agent['ratingCount'] ?? '0').toString()) ?? 0;
    final avgRating = ratingCount > 0 ? (ratingSum / ratingCount) : null;

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

    DateTime? approvedAt;
    final approvedRaw = json['approvedAt']?.toString();
    if (approvedRaw != null && approvedRaw.isNotEmpty) {
      approvedAt = DateTime.tryParse(approvedRaw);
    }

    DateTime? userConfirmedAt;
    final userConfirmedRaw = json['userConfirmedAt']?.toString();
    if (userConfirmedRaw != null && userConfirmedRaw.isNotEmpty) {
      userConfirmedAt = DateTime.tryParse(userConfirmedRaw);
    }

    DateTime? agentConfirmedAt;
    final agentConfirmedRaw = json['agentConfirmedAt']?.toString();
    if (agentConfirmedRaw != null && agentConfirmedRaw.isNotEmpty) {
      agentConfirmedAt = DateTime.tryParse(agentConfirmedRaw);
    }

    int? userRating;
    final ratingRaw = json['userRating'];
    if (ratingRaw != null) {
      userRating = int.tryParse(ratingRaw.toString());
    }

    DateTime? ratedAt;
    final ratedRaw = json['ratedAt']?.toString();
    if (ratedRaw != null && ratedRaw.isNotEmpty) {
      ratedAt = DateTime.tryParse(ratedRaw);
    }

    return _UserRequestItem(
      id: (json['id'] ?? '').toString(),
      agentId: (json['agentId'] ?? agent['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString().toLowerCase(),
      requestType: (json['requestType'] ?? '').toString(),
      amount: int.tryParse((json['amount'] ?? '0').toString()) ?? 0,
        agentCommission: int.tryParse((json['agentCommission'] ?? '0').toString()) ?? 0,
        totalPaid: int.tryParse((json['totalPaid'] ?? json['amount'] ?? '0').toString()) ??
          (int.tryParse((json['amount'] ?? '0').toString()) ?? 0),
        agentReceived:
          int.tryParse((json['agentReceived'] ?? json['totalPaid'] ?? json['amount'] ?? '0').toString()) ??
            (int.tryParse((json['totalPaid'] ?? json['amount'] ?? '0').toString()) ?? 0),
      agentName: (agentUser['name'] ?? 'Agent').toString(),
      agentPhone: (agentUser['phone'] ?? '').toString(),
      agentEmail: (agentUser['email'] ?? '').toString(),
      shopName: (agent['locationName'] ?? '').toString(),
      address: (agentUser['address'] ?? '').toString(),
      city: (agent['city'] ?? 'Unknown city').toString(),
      agentAverageRating: avgRating,
      agentRatingCount: ratingCount,
      approvedAt: approvedAt,
      userConfirmedAt: userConfirmedAt,
      agentConfirmedAt: agentConfirmedAt,
      userRating: userRating,
      ratedAt: ratedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
    );
  }

  static _UserRequestItem empty() {
    return _UserRequestItem(
      id: '',
      agentId: '',
      amount: 0,
      agentCommission: 0,
      totalPaid: 0,
      agentReceived: 0,
      status: '',
      requestType: '',
      agentName: '',
      agentPhone: '',
      agentEmail: '',
      agentAverageRating: null,
      agentRatingCount: 0,
      createdAt: null,
      updatedAt: null,
      completedAt: null,
      approvedAt: null,
      userConfirmedAt: null,
      agentConfirmedAt: null,
      userRating: null,
      ratedAt: null,
      shopName: '',
      address: '',
      city: '',
    );
  }
}
