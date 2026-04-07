part of 'available_agents_screen.dart';

// -------------------------------------------------------
// Card
// -------------------------------------------------------
class _AgentCard extends StatelessWidget {
  final _AgentSummary agent;
  final String transactionType;
  final String amount;
  final bool isRequesting;
  final _RequestState? requestState;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final void Function(_RequestState state) onClear;

  const _AgentCard({
    required this.agent,
    required this.transactionType,
    required this.amount,
    required this.isRequesting,
    required this.requestState,
    required this.onRequest,
    required this.onCancel,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE6EBF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF5E4AE3).withValues(alpha: 0.12),
                backgroundImage: agent.profilePhotoBytes != null
                    ? MemoryImage(agent.profilePhotoBytes!)
                    : null,
                child: agent.profilePhotoBytes == null
                    ? Text(
                        agent.name.isNotEmpty
                            ? agent.name[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5E4AE3),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffECFDF3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: Color(0xff059669)),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFF7E6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xffB45309),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                agent.averageRating == null
                                    ? 'New'
                                    : '${agent.averageRating!.toStringAsFixed(1)} (${agent.ratingCount})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xffB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (agent.locationName.isNotEmpty)
                      Text(
                        agent.locationName,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      agent.city,
                      style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.distanceKm != null
                          ? '${agent.distanceKm!.toStringAsFixed(1)} km • Available now'
                          : 'Available now',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: _buildActionArea(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea() {
    final status = requestState?.status;

    if (isRequesting) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E4AE3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Requested',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff4338CA)),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    if (status == 'rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xffFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Rejected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xffDC2626)),
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Request'),
          ),
        ],
      );
    }

    if (status == 'approved') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xffECFDF3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffA7F3D0)),
            ),
            child: const Text(
              'Approved',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xff065F46),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Request Again'),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: onRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      child: const Text('Request'),
    );
  }
}
