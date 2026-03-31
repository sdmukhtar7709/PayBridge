import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../config/api_config.dart';
import '../../../services/agent_rating_live_store.dart';
import '../../../services/auth_service.dart';
import '../home/user_home_screen.dart';
import 'my_requests_screen.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final String amount;
  final String agentName;
  final String agentPhone;
  final String city;
  final String shopName;
  final String? transactionId;
  final DateTime? transactionDateTime;

  const TransactionSuccessScreen({
    super.key,
    required this.amount,
    required this.agentName,
    required this.agentPhone,
    required this.city,
    required this.shopName,
    this.transactionId,
    this.transactionDateTime,
  });

  @override
  State<TransactionSuccessScreen> createState() => _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen>
    with SingleTickerProviderStateMixin {
  static final String _apiBaseUrl = ApiConfig.baseUrl;
  late final AnimationController _pulseController;
  late final Animation<double> _iconScale;
  bool _isNavigatingHome = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _iconScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txTime = widget.transactionDateTime ?? DateTime.now();
    final timeLabel = _formatDateTime(txTime);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBackHomePressed();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7FB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackHomePressed,
          ),
          title: const Text('Transaction Successful'),
          backgroundColor: const Color(0xffF5F7FB),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xffDDE3EE)),
                          ),
                          child: Column(
                            children: [
                              _animatedSuccessIcon,
                              const SizedBox(height: 10),
                              const Text(
                                'Transaction Successful',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff0F172A),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '₹${widget.amount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff111827),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xff64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Other Party',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv('Agent', widget.agentName),
                              _kv('Phone', _safe(widget.agentPhone)),
                              _kv('Shop', _safe(widget.shopName)),
                              _kv('City', _safe(widget.city)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          title: 'Security',
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xff15803D)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'OTP verified successfully',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => MyRequestsScreen(initialRequestId: widget.transactionId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Color(0xff0F172A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xff0F172A)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _onBackHomePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff16A34A),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onBackHomePressed() async {
    if (_isNavigatingHome) return;
    _isNavigatingHome = true;

    final transactionId = widget.transactionId?.trim() ?? '';
    if (transactionId.isNotEmpty) {
      await _showRatingConfirmBox(transactionId);
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showRatingConfirmBox(String transactionId) async {
    int selectedRating = 5;
    final commentController = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Rate Your Experience'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please give a rating before going home.'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () => setLocalState(() => selectedRating = value),
                          icon: Icon(
                            value <= selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'Comment (optional)',
                        hintText: 'Write your feedback',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit == true) {
      await _submitRating(transactionId, selectedRating, commentController.text.trim());
    }
    commentController.dispose();
  }

  Future<void> _submitRating(String transactionId, int rating, String comment) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/transactions/requests/$transactionId/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rating': rating,
          if (comment.isNotEmpty) 'comment': comment,
        }),
      );

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final agentId = (body['agentId'] ?? '').toString();
        final avgRaw = body['agentRatingAverage'];
        final countRaw = body['agentRatingCount'];
        final avg = avgRaw is num ? avgRaw.toDouble() : double.tryParse('$avgRaw');
        final count = countRaw is int ? countRaw : int.tryParse('$countRaw') ?? 0;
        if (agentId.isNotEmpty && avg != null && count > 0) {
          AgentRatingLiveStore.instance.emit(
            AgentRatingLiveUpdate(
              agentId: agentId,
              averageRating: avg,
              ratingCount: count,
            ),
          );
        }
        final message = avg == null || count <= 0
            ? 'Thank you for your rating!'
            : 'Thank you! Agent rating is now ${avg.toStringAsFixed(1)} ($count)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating already submitted for this transaction.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit rating right now.')),
      );
    }
  }

  Widget get _animatedSuccessIcon {
    return ScaleTransition(
      scale: _iconScale,
      child: const Icon(Icons.check_circle_rounded, size: 84, color: Color(0xff16A34A)),
    );
  }

  String _safe(String value) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }

  String _formatDateTime(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final yyyy = dateTime.year.toString();
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy  $hh:$min';
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE3E8F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xff475569),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xff111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
