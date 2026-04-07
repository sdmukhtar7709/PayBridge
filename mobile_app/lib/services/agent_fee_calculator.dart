class AgentFeeBreakdown {
  final int amount;
  final int agentFee;
  final int totalPayable;
  final int agentReceives;

  const AgentFeeBreakdown({
    required this.amount,
    required this.agentFee,
    required this.totalPayable,
    required this.agentReceives,
  });

  bool get feeApplied => agentFee > 0;
}

class AgentFeeCalculator {
  static const int feeThreshold = 1000;
  static const double feeRate = 0.005;

  static AgentFeeBreakdown fromAmount(int amount) {
    final normalized = amount < 0 ? 0 : amount;
    final fee = normalized >= feeThreshold ? (normalized * feeRate).round() : 0;
    final total = normalized + fee;
    return AgentFeeBreakdown(
      amount: normalized,
      agentFee: fee,
      totalPayable: total,
      agentReceives: total,
    );
  }

  static AgentFeeBreakdown fromRawAmount(String rawAmount) {
    final sanitized = rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsed = num.tryParse(sanitized);
    return fromAmount(parsed?.round() ?? 0);
  }
}
