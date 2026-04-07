import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent_home_screen.dart';
import 'agent_transactions_screen.dart';

class AgentTransactionSuccessScreen extends StatefulWidget {
  final String userName;
  final int amount;
  final int agentCommission;
  final int totalReceived;
  final DateTime? transactionDateTime;

  const AgentTransactionSuccessScreen({
    super.key,
    required this.userName,
    required this.amount,
    required this.agentCommission,
    required this.totalReceived,
    this.transactionDateTime,
  });

  @override
  State<AgentTransactionSuccessScreen> createState() => _AgentTransactionSuccessScreenState();
}

class _AgentTransactionSuccessScreenState extends State<AgentTransactionSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _iconScale;

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

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
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
                              '₹${widget.totalReceived}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Color(0xff111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Commission Earned',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xff64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${widget.agentCommission}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xff0F172A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDateTime(txTime),
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
                        title: 'Transaction Summary',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _kv('Transaction Amount', '₹${widget.amount}'),
                            _kv('Your Earnings', '₹${widget.agentCommission}'),
                            _kv('Total Received', '₹${widget.totalReceived}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Other Party',
                        child: _kv('User', widget.userName.trim().isEmpty ? '-' : widget.userName),
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
                    MaterialPageRoute(builder: (_) => const AgentTransactionsScreen()),
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
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AgentHomeScreen()),
                    (route) => false,
                  );
                },
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
    );
  }

  Widget get _animatedSuccessIcon {
    return ScaleTransition(
      scale: _iconScale,
      child: const Icon(Icons.check_circle_rounded, size: 84, color: Color(0xff16A34A)),
    );
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
    return Row(
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
    );
  }
}
