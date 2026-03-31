import 'package:flutter/material.dart';

class ReceiptPersonData {
  final String name;
  final String phone;
  final String shopName;
  final String city;
  final String address;
  final String ratingLabel;

  const ReceiptPersonData({
    required this.name,
    required this.phone,
    this.shopName = '',
    this.city = '',
    this.address = '',
    this.ratingLabel = '',
  });
}

class TransactionReceiptView extends StatelessWidget {
  final String status;
  final int amount;
  final String dateTimeLabel;
  final ReceiptPersonData agentDetails;
  final ReceiptPersonData userDetails;
  final String transactionId;
  final String requestType;
  final String city;
  final String fullAddress;
  final bool emphasizeAgentDetails;
  final bool? otpVerified;
  final bool? confirmedByAgent;
  final bool? confirmedByUser;

  const TransactionReceiptView({
    super.key,
    required this.status,
    required this.amount,
    required this.dateTimeLabel,
    required this.agentDetails,
    required this.userDetails,
    required this.transactionId,
    required this.requestType,
    required this.city,
    required this.fullAddress,
    required this.emphasizeAgentDetails,
    this.otpVerified,
    this.confirmedByAgent,
    this.confirmedByUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _statusInfo(status);
    final formattedStatus = info.label;

    return Scaffold(
      backgroundColor: const Color(0xffF3F6FB),
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildHeader(info, theme),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'People',
              icon: Icons.people_alt_outlined,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 720;
                  final spacing = const SizedBox(width: 12, height: 12);

                  final agentCard = _buildPersonCard(
                    title: 'Agent Details',
                    person: agentDetails,
                    emphasize: emphasizeAgentDetails,
                    showShop: true,
                    icon: Icons.storefront_outlined,
                  );
                  final userCard = _buildPersonCard(
                    title: 'User Details',
                    person: userDetails,
                    emphasize: !emphasizeAgentDetails,
                    showShop: false,
                    icon: Icons.person_outline,
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: agentCard),
                        spacing,
                        Expanded(child: userCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      agentCard,
                      const SizedBox(height: 12),
                      userCard,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Transaction Details',
              icon: Icons.receipt_long_outlined,
              child: Column(
                children: [
                  _kv('Transaction ID', transactionId),
                  _kv('Request Type', _requestTypeLabel(requestType)),
                  _kv('Amount', '₹$amount'),
                  _kv('Status', formattedStatus),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Verification & Security',
              icon: Icons.verified_user_outlined,
              child: Column(
                children: [
                  _secureRow('OTP Verified', otpVerified),
                  _secureRow('Confirmed by Agent', confirmedByAgent),
                  _secureRow('Confirmed by User', confirmedByUser),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Location Details',
              icon: Icons.location_on_outlined,
              child: Column(
                children: [
                  _kv('City', _safe(city)),
                  _kv('Full Address', _safe(fullAddress)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Transaction Timeline',
              icon: Icons.timeline_outlined,
              child: _Timeline(
                steps: [
                  _TimelineStep(label: 'Requested', done: true),
                  _TimelineStep(label: 'Accepted', done: _isAccepted(status)),
                  _TimelineStep(label: 'OTP Verified', done: otpVerified ?? false),
                  _TimelineStep(label: 'Completed', done: info.kind == _ReceiptStatusKind.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_ReceiptStatusInfo info, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            info.color.withValues(alpha: 0.95),
            info.color.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                info.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹$amount',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateTimeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard({
    required String title,
    required ReceiptPersonData person,
    required bool emphasize,
    required bool showShop,
    required IconData icon,
  }) {
    final accent = emphasize ? const Color(0xff0B57D0) : const Color(0xff9AA4B2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xffEEF4FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: emphasize ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoLine('Name', _safe(person.name)),
          if (person.ratingLabel.trim().isNotEmpty)
            _infoLine('Rating', person.ratingLabel.trim()),
          _infoLine('Phone', _safe(person.phone)),
          if (showShop) ...[
            _infoLine('Shop', _safe(person.shopName)),
            _infoLine('City', _safe(person.city)),
          ],
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff5F6B7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xff1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secureRow(String label, bool? isDone) {
    final done = isDone == true;
    final pending = isDone == null;
    final color = done
        ? const Color(0xff15803D)
        : pending
            ? const Color(0xffA16207)
            : const Color(0xffB91C1C);
    final icon = done
        ? Icons.check_circle
        : pending
            ? Icons.schedule
            : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            done ? 'Verified' : (pending ? 'Pending' : 'Not Verified'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              key,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xff5F6B7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
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

  bool _isAccepted(String rawStatus) {
    final s = rawStatus.trim().toLowerCase();
    return s == 'approved' ||
        s == 'confirmed' ||
        s == 'completed' ||
        s == 'success' ||
        s == 'failed' ||
        s == 'rejected';
  }

  String _requestTypeLabel(String rawType) {
    final value = rawType.trim().toLowerCase();
    if (value.isEmpty) return '-';
    if (value == 'upi_to_cash' || value == 'upi to cash') {
      return 'UPI → Cash';
    }
    if (value == 'cash_deposit' || value == 'cash deposit') {
      return 'Cash Deposit';
    }
    if (value == 'cash_to_upi' || value == 'cash to upi') {
      return 'Cash to UPI';
    }
    return rawType;
  }

  String _safe(String value) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }

  _ReceiptStatusInfo _statusInfo(String rawStatus) {
    final value = rawStatus.trim().toLowerCase();
    if (value == 'confirmed' || value == 'completed' || value == 'success') {
      return const _ReceiptStatusInfo(
        label: 'Success',
        color: Color(0xff15803D),
        icon: Icons.check_circle_outline,
        kind: _ReceiptStatusKind.success,
      );
    }
    if (value == 'pending' || value == 'approved') {
      return const _ReceiptStatusInfo(
        label: 'Pending',
        color: Color(0xffC27803),
        icon: Icons.schedule,
        kind: _ReceiptStatusKind.pending,
      );
    }
    return const _ReceiptStatusInfo(
      label: 'Failed',
      color: Color(0xffB42318),
      icon: Icons.cancel_outlined,
      kind: _ReceiptStatusKind.failed,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xff334155)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  final String label;
  final bool done;

  const _TimelineStep({required this.label, required this.done});
}

class _Timeline extends StatelessWidget {
  final List<_TimelineStep> steps;

  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canUseRow = constraints.maxWidth > 320;
        if (!canUseRow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in steps) ...[
                _TimelineLabel(step: step),
                const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(child: _TimelineLabel(step: steps[i])),
              if (i != steps.length - 1)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    height: 2,
                    color: steps[i].done ? const Color(0xff15803D) : const Color(0xffD0D5DD),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TimelineLabel extends StatelessWidget {
  final _TimelineStep step;

  const _TimelineLabel({required this.step});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? const Color(0xff15803D) : const Color(0xff667085);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          step.done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

enum _ReceiptStatusKind { success, pending, failed }

class _ReceiptStatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  final _ReceiptStatusKind kind;

  const _ReceiptStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
    required this.kind,
  });
}
